## Task

Create a CronJob named `backup-job` in namespace `default` with the following specifications:

- Schedule: Run every 30 minutes (`*/30 * * * *`)
- Image: `busybox:latest`
- Container command: `echo "Backup completed"`
- Set `successfulJobsHistoryLimit: 3`
- Set `failedJobsHistoryLimit: 2`
- Set `activeDeadlineSeconds: 300`
- Use `restartPolicy: Never`

Do not create any additional resources unless required by your solution.
