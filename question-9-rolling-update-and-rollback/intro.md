This scenario starts with a Deployment `app-v1` running `nginx:1.20` in namespace `default`.

Your job is to perform a rolling update to `nginx:1.25`, confirm it worked, then rollback to the previous revision.
