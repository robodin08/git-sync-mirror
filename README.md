# git-sync-mirror

[![Docker Pulls](https://img.shields.io/docker/pulls/robodin08/git-sync-mirror)](https://hub.docker.com/r/robodin08/git-sync-mirror)

*A Docker container for continuously mirroring a Git repository to another repository over HTTPS.*

## Features

- **One-way synchronization:** mirror branches and tags from a source repository to a destination repository.
- **HTTPS token authentication:** authenticate with access tokens for private repositories.
- **Optional pruning:** remove destination branches and tags that no longer exist in the source.
- **Optional force push:** allow source changes to overwrite destination history.
- **Shoutrrr notifications:** receive notifications when synchronization fails and when it recovers.
- **Automatic retries:** keep retrying after failures instead of exiting.
- **Configurable interval:** control the delay between synchronization attempts.
- **HTTP proxy support:** configure separate proxies for the source and destination.
- **TLS certificate verification:** verify HTTPS certificates by default.
- **One-shot mode:** synchronize once and exit after a successful run.

## How it works

The container clones the source repository into a local mirror and periodically fetches updates. It then pushes branches and tags to the destination repository.

When synchronization fails, the container retries after the configured `SLEEP_TIME`. If notifications are configured, it sends one failure notification per incident and a recovery notification after a subsequent successful synchronization.

This is a **one-way mirror**: changes made directly to the destination are not synchronized back to the source.

## Quick start

```bash
docker run -d \
  --name git-sync-mirror \
  --restart unless-stopped \
  -e SRC_REPO="https://github.com/OWNER/SOURCE.git" \
  -e DST_REPO="https://github.com/OWNER/DESTINATION.git" \
  -e SLEEP_TIME="60s" \
  robodin08/git-sync-mirror:latest
```

Replace the repository URLs with your own. For private repositories, configure the relevant access tokens as described below.

## Docker Compose

Create a `docker-compose.yml` file:

```yml
services:
  git-sync-mirror:
    image: robodin08/git-sync-mirror:latest
    container_name: git-sync-mirror
    restart: unless-stopped

    environment:
      SRC_REPO: ${SRC_REPO}
      DST_REPO: ${DST_REPO}

      SRC_REPO_TOKEN: ${SRC_REPO_TOKEN:-}
      SRC_REPO_TOKEN_USER: ${SRC_REPO_TOKEN_USER:-}
      DST_REPO_TOKEN: ${DST_REPO_TOKEN:-}
      DST_REPO_TOKEN_USER: ${DST_REPO_TOKEN_USER:-}

      SLEEP_TIME: "60s"
      PRUNE: "false"
      GIT_FORCE_PUSH: "false"
      HTTP_TLS_VERIFY: "true"

      SHOUTRRR_URL: ${SHOUTRRR_URL:-}
      NOTIFY_ON_FAILURE: "true"
      NOTIFY_ON_RECOVERY: "true"
```

Create a `.env` file in the same directory:

```dotenv
SRC_REPO=https://github.com/OWNER/SOURCE.git
DST_REPO=https://github.com/OWNER/DESTINATION.git

SRC_REPO_TOKEN=
SRC_REPO_TOKEN_USER=
DST_REPO_TOKEN=
DST_REPO_TOKEN_USER=

SHOUTRRR_URL=
```

Fill in the repository URLs and credentials as needed. Configure `SHOUTRRR_URL` using a supported Shoutrrr service URL if you want notifications.

Start the mirror:

```bash
docker compose up -d
```

View logs:

```bash
docker compose logs -f git-sync-mirror
```

Stop the mirror:

```bash
docker compose down
```

**Security:** treat `.env` as sensitive, restrict its permissions, and do not commit it to version control. For production deployments, use your platform's secrets mechanism where available.

## Environment variables

### Repository configuration

| Variable | Description | Required | Default |
|---|---|:---:|---|
| `SRC_REPO` | URL of the source Git repository. | Yes | — |
| `DST_REPO` | URL of the destination Git repository. | Yes | — |
| `SRC_LOCAL_REPO` | Path to the local source mirror directory. | No | Temporary directory |
| `SRC_REPO_TOKEN` | Access token for the source repository. | No | Empty |
| `DST_REPO_TOKEN` | Access token for the destination repository. | No | Empty |
| `SRC_REPO_TOKEN_USER` | Username associated with the source token, if required by the provider. | No | Empty |
| `DST_REPO_TOKEN_USER` | Username associated with the destination token, if required by the provider. | No | Empty |

Tokens are optional for public repositories. For private repositories, the token must have the permissions required to read the source or write to the destination.

### Synchronization

| Variable | Description | Default |
|---|---|---|
| `SLEEP_TIME` | Delay between synchronization attempts. | `60s` |
| `ONCE` | Synchronize once successfully, then exit. Failed attempts are retried. | `false` |
| `PRUNE` | Remove destination branches and tags that no longer exist in the source. | `false` |
| `GIT_FORCE_PUSH` | Allow forced updates to destination branches and tags. | `false` |
| `IGNORE_REFS_PATTERN` | Refs to exclude from the mirror, such as GitHub pull-request refs. | `refs/pull` |
| `DEBUG` | Enable verbose Bash debugging. | `false` |

Use `PRUNE=true` carefully: it can delete branches and tags from the destination. `GIT_FORCE_PUSH=true` can overwrite destination history.

The `SLEEP_TIME` value uses a duration accepted by the `sleep` command, such as `30s`, `5m`, or `1h`.

### Notifications

| Variable | Description | Default |
|---|---|---|
| `SHOUTRRR_URL` | Shoutrrr service URL used to deliver notifications. | Empty |
| `NOTIFY_ON_FAILURE` | Send a notification when a synchronization incident starts. | `true` |
| `NOTIFY_ON_RECOVERY` | Send a notification when synchronization recovers. | `true` |

If `SHOUTRRR_URL` is empty, notifications are skipped. The mirror continues running.

A continuous failure produces one failure notification until synchronization succeeds again. A subsequent failure after recovery starts a new incident.

Incident state is held in memory, so restarting the container during an outage can cause another failure notification.

See the [Shoutrrr documentation](https://shoutrrr.nickfedor.com/v0.22.1/) for supported notification services and URL formats.

### HTTP and TLS

| Variable | Description | Default |
|---|---|---|
| `HTTP_TLS_VERIFY` | Enable or disable Git HTTPS certificate verification. | `true` |
| `HTTP_SRC_PROXY` | HTTP proxy used when connecting to the source repository. | Empty |
| `HTTP_DST_PROXY` | HTTP proxy used when connecting to the destination repository. | Empty |
| `HTTP_ALLOW_TOKENS_INSECURE` | Permit token injection into HTTP URLs instead of requiring HTTPS. | `false` |

Keep `HTTP_TLS_VERIFY=true` and use HTTPS for authenticated repositories. Disabling certificate verification or transmitting tokens over HTTP can expose credentials.

## Authentication

For private repositories, supply access tokens through `SRC_REPO_TOKEN` and `DST_REPO_TOKEN`.

For example, with GitHub:

- The source token needs repository read access.
- The destination token needs repository write access.
- `SRC_REPO_TOKEN_USER` and `DST_REPO_TOKEN_USER` should be set to the appropriate username if required by the provider.

Use tokens with the minimum required permissions. Avoid enabling `DEBUG=true` when credentials are configured, because verbose shell tracing may expose sensitive information.

## Operational notes

- **Destination changes:** this container does not pull changes from the destination back into the source.
- **Pruning:** enable `PRUNE=true` only when the destination should reflect branch and tag deletions from the source.
- **Persistence:** the default source mirror uses a temporary directory. If you configure `SRC_LOCAL_REPO` to use persistent storage, ensure the directory is writable by the container's configured user.
- **Retries:** a failed clone, fetch, or push should be retried after `SLEEP_TIME`.
- **Notifications:** notification delivery failures should not stop repository synchronization.
- **One-shot execution:** use `ONCE=true` for a job that should exit after a successful synchronization.

## License

See [LICENSE](LICENSE) for license details.