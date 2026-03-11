# Frequently asked questions


This guide provides troubleshooting steps and resolutions for common infrastructure and networking issues encountered during the containerization and deployment process. It is intended for users who intend to set up the application



## Issue 1: Access Issue for github.com

### Context
While building docker images and containers using `docker compose`, the process may fail with an error in the logs similar to:
`fatal: unable to access 'https://github.com/...': Failed to connect to github.com port 443`

### Reason
Network restrictions are likely preventing the `git clone` command from executing. Verify this by running the following command from your Ubuntu VM:
```bash
git clone [https://github.com/github/docs.git](https://github.com/github/docs.git)
```

### Solution

Contact your Company's network team to check for firewall rules restricting access to github.com.