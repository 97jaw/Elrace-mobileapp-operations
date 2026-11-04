# -*- coding: utf-8 -*-
"""Commands: check-config, check-render, check-events, report."""

import argparse
import os
import sys

import yaml

from .checks import check_config, check_events, check_render, parse_since
from .client import OdooClient, ReadOnlyError
from .report import write_report

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_SPEC = os.path.join(_HERE, 'expected_types.yaml')
_OUT = os.path.join(_HERE, 'out')


def load_spec(path=None):
    with open(path or _SPEC, 'r', encoding='utf-8') as handle:
        data = yaml.safe_load(handle)
    return data['types']


def _fault_line(exc):
    text = str(exc).replace('\\n', '\n')
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    useful = [line for line in lines if not line.startswith('File ')]
    return (useful[-1] if useful else text)[:500]


def _print_result(name, result):
    status = 'PASS' if result.get('ok') else 'FAIL'
    print('%s: %s' % (name, status))
    for issue in result.get('issues') or []:
        code = issue.get('code') or ''
        field = issue.get('field') or ''
        problem = issue.get('problem') or ''
        extra = ''
        if 'expected' in issue or 'actual' in issue:
            extra = ' expected=%r actual=%r' % (issue.get('expected'), issue.get('actual'))
        print('  - %s %s %s%s' % (code, field, problem, extra))
    return 0 if result.get('ok') else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description='Read-only notification checks against Odoo.')
    parser.add_argument('command', choices=('check-config', 'check-render', 'check-events', 'report'))
    parser.add_argument('--since', default='24h')
    parser.add_argument('--type', dest='type_code', default=None)
    parser.add_argument('--include-shadow', action='store_true')
    parser.add_argument('--spec', default=_SPEC)
    parser.add_argument('--out', default=_OUT)
    args = parser.parse_args(argv)
    try:
        spec = load_spec(args.spec)
        client = OdooClient.from_env().connect()
        if args.command == 'check-config':
            return _print_result('check-config', check_config(client, spec))
        if args.command == 'check-render':
            return _print_result('check-render', check_render(client, spec))
        if args.command == 'check-events':
            result = check_events(
                client, parse_since(args.since), args.type_code, args.include_shadow,
            )
            return _print_result('check-events', result)
        results = {
            'check-config': check_config(client, spec),
            'check-render': check_render(client, spec),
            'check-events': check_events(client, parse_since(args.since), args.type_code, args.include_shadow),
        }
        md_path, json_path = write_report(args.out, results)
        code = 0
        for name, result in results.items():
            code = code or _print_result(name, result)
        print('report: %s' % md_path)
        print('report: %s' % json_path)
        return code
    except ReadOnlyError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except Exception as exc:
        print(_fault_line(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
