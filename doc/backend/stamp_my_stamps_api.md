# Stamp APIs — live in `elrace_backend_apis`

Path: `/Users/mjawad/projects/elrace/odoo14-clients/elrace_backend_apis`

| Endpoint | File | Purpose |
|----------|------|---------|
| `POST /api/users/my_stamps` | `controllers/users_controller.py` | Stamp binaries on Apply Stamp |
| Login `data.x_stamp_user` | `controllers/auth_controller.py` | Boolean only (no binaries on login) |

Upgrade module on server after deploy: `-u elrace_backend_apis`
