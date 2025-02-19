# GitLab Token Management Script

## Usage

### Expire Tokens
```bash
./gitlab-rake-tokens.sh expire {analyze|extend} [OPTIONS]
```
- `analyze` - Check tokens expiring in the next `X` days.
- `extend`  - Extend tokens expiring in the next `X` days.

**Options:**
- `-d, --days <days>` (Required) Days to check ahead.
- `-e, --extend <days>` (Required for extend) Days to extend.
- `-u, --user <user1,user2,...>` (Optional) Filter by user IDs.

### User Tokens
```bash
./gitlab-rake-tokens.sh user {analyze|extend} [OPTIONS]
```
- `analyze` - Check tokens for specific users.
- `extend`  - Extend user tokens.

**Options:**
- `-u, --user <user1,user2,...>` (Required) User IDs.
- `-e, --extend <days>` (Required for extend) Days to extend.
- `-t, --token <token1,token2,...>` (Optional) Filter by token IDs.

## Examples

### Expire Tokens
```bash
./gitlab-rake-tokens.sh expire analyze -d 7
./gitlab-rake-tokens.sh expire extend -d 7 -e 30
./gitlab-rake-tokens.sh expire extend -d 7 -e 30 -u 1,2
```

### User Tokens
```bash
./gitlab-rake-tokens.sh user analyze -u 1,2
./gitlab-rake-tokens.sh user extend -u 1,2 -e 30
./gitlab-rake-tokens.sh user extend -u 1,2 -e 30 -t 10,20
```

## Notes
- Requires `sudo` for `gitlab-rails runner`.
- Ensure GitLab supports `gitlab-rails runner`.
- Logs are color-coded for clarity.
