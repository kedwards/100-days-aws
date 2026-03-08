# Day 01 - Linux User Setup with Non-Interactive Shell

## Task

To accommodate the backup agent tool's specifications, the system admin team at xFusionCorp Industries requires the creation of a user with a non-interactive shell. Here's your task:

Create a user named anita with a non-interactive shell on App Server 2.

### Infrastructure

App Server 2: stapp02 (172.16.238.11), user: steve

## Help

```bash
useradd --help
getent --help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
server="stapp02"
server_user="steve"
username="anita"
shell="/sbin/nologin"

# ── Create user with non-interactive shell ────────────────────
ssh "$server_user@$server" \
  "sudo -S useradd -s $shell $username" && echo "Created user: $username"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
ssh steve@stapp02 "getent passwd anita"
ssh steve@stapp02 "id anita"
```

```bash
server="stapp02"
server_user="steve"
username="anita"
expected_shell="/sbin/nologin"

# Get user shell from passwd
actual_shell=$(ssh "$server_user@$server" \
  "getent passwd $username" 2>/dev/null | cut -d: -f7) && echo "Shell: $actual_shell"

# Check user exists
user_exists=$(ssh "$server_user@$server" \
  "id $username" &>/dev/null && echo "true" || echo "false") && echo "User exists: $user_exists"

# Validation checks
shell_valid=false
exists_valid=false

[[ "$actual_shell" == "$expected_shell" ]] && shell_valid=true
[[ "$user_exists" == "true" ]] && exists_valid=true

if [[ "$shell_valid" == true ]] && [[ "$exists_valid" == true ]]; then
  echo "✓ Success"
  echo "  User: $username"
  echo "  Shell: $actual_shell"
else
  echo "✗ Fail"

  if [[ "$exists_valid" == false ]]; then
    echo "  ✗ User does not exist"
    echo "    Expected: $username"
  else
    echo "  ✓ User exists"
  fi

  if [[ "$shell_valid" == false ]]; then
    echo "  ✗ Shell mismatch"
    echo "    Expected: $expected_shell"
    echo "    Got: $actual_shell"
  else
    echo "  ✓ Shell is non-interactive"
  fi
fi
```

</details>
