# -*- coding: utf-8 -*-
"""Read-only XML-RPC. Credentials come from the environment and are never printed."""

import os
import xmlrpc.client

ENV_VARS = ('ODOO_URL', 'ODOO_DB', 'ODOO_LOGIN', 'ODOO_API_KEY')
_READ_METHODS = frozenset(('search_read', 'read', 'search', 'fields_get'))


class ReadOnlyError(RuntimeError):
    pass


class OdooClient(object):
    def __init__(self, url, db, login, api_key):
        self.url = url.rstrip('/')
        self.db = db
        self.login = login
        self._api_key = api_key
        self._uid = None
        self._models = None

    @classmethod
    def from_env(cls):
        missing = [name for name in ENV_VARS if not os.environ.get(name)]
        if missing:
            raise ReadOnlyError(
                'Set %s in the environment. The API key is not a password and is never printed.'
                % ', '.join(missing)
            )
        return cls(
            os.environ['ODOO_URL'],
            os.environ['ODOO_DB'],
            os.environ['ODOO_LOGIN'],
            os.environ['ODOO_API_KEY'],
        )

    def connect(self):
        common = xmlrpc.client.ServerProxy(
            self.url + '/xmlrpc/2/common', allow_none=True,
        )
        uid = common.authenticate(self.db, self.login, self._api_key, {})
        if not uid:
            raise ReadOnlyError('Odoo authentication failed.')
        self._uid = uid
        self._models = xmlrpc.client.ServerProxy(
            self.url + '/xmlrpc/2/object', allow_none=True,
        )
        return self

    def execute(self, model, method, args=None, kwargs=None):
        if method in ('create', 'write', 'unlink', 'copy', 'default_get'):
            raise ReadOnlyError('refusing %s.%s' % (model, method))
        if method == 'preview':
            if model != 'elrace.notify.type':
                raise ReadOnlyError('preview is only allowed on elrace.notify.type')
        elif method not in _READ_METHODS:
            raise ReadOnlyError('refusing %s.%s' % (model, method))
        if self._models is None:
            self.connect()
        return self._models.execute_kw(
            self.db, self._uid, self._api_key, model, method, args or [], kwargs or {},
        )

    def search_read(self, model, domain, fields, limit=0, order=None):
        # Types and categories are seeded inactive. active_test would hide every row.
        kwargs = {'fields': fields, 'context': {'active_test': False}}
        if limit:
            kwargs['limit'] = limit
        if order:
            kwargs['order'] = order
        return self.execute(model, 'search_read', [domain], kwargs)

    def preview(self, code, values):
        rendered = self.execute('elrace.notify.type', 'preview', [code, values or {}])
        if not isinstance(rendered, dict):
            raise ReadOnlyError('preview returned an unexpected payload')
        return {
            'title': '' if rendered.get('title') in (None, False) else str(rendered.get('title')),
            'body': '' if rendered.get('body') in (None, False) else str(rendered.get('body')),
        }

    def record_link(self, model, res_id):
        if not model or not res_id:
            return ''
        return '%s/web#id=%s&model=%s&view_type=form' % (self.url, res_id, model)
