# -*- coding: utf-8 -*-
"""Write the local markdown and JSON report. Never includes credentials."""

import json
import os


def write_report(folder, results):
    os.makedirs(folder, exist_ok=True)
    json_path = os.path.join(folder, 'notify_check.json')
    md_path = os.path.join(folder, 'notify_check.md')
    with open(json_path, 'w', encoding='utf-8') as handle:
        json.dump(results, handle, indent=2, sort_keys=True, default=str)
        handle.write('\n')
    lines = ['# Notification check', '']
    for name, result in results.items():
        if not isinstance(result, dict) or 'ok' not in result:
            continue
        status = 'PASS' if result.get('ok') else 'FAIL'
        lines.append('## %s — %s' % (name, status))
        lines.append('')
        for issue in result.get('issues') or []:
            bits = []
            if issue.get('code'):
                bits.append('`%s`' % issue['code'])
            if issue.get('field'):
                bits.append(str(issue['field']))
            if issue.get('problem'):
                bits.append(str(issue['problem']))
            if 'expected' in issue or 'actual' in issue:
                bits.append('expected %r actual %r' % (issue.get('expected'), issue.get('actual')))
            if issue.get('link'):
                bits.append(issue['link'])
            lines.append('- ' + ' — '.join(bits))
        if not result.get('issues'):
            lines.append('- no issues')
        lines.append('')
    with open(md_path, 'w', encoding='utf-8') as handle:
        handle.write('\n'.join(lines))
    return md_path, json_path
