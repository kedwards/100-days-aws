# Day 02 - Temporary User Setup with Expiry

## Task

As part of the temporary assignment to the Nautilus project, a developer named mariyam requires access for a limited duration. To ensure smooth access management, a temporary user account with an expiry date is needed. Here's what you need to do:

Create a user named mariyam on App Server 3 in Stratos Datacenter. Set the expiry date to 2027-04-15, ensuring the user is created in lowercase as per standard protocol.

### Infrastructure

App Server 3: stapp03 (172.16.238.12), user: banner

## Help

```bash
useradd --help
chage --help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
server="stapp03"
server_user="banner"
username="mariyam"
expiry_date="2027-04-15"

# ── Create user with expiry date ──────────────────────────────
ssh "$server_user@$server" \
  "sudo useradd -e $expiry_date $username" && echo "Created user: $username (expires: $expiry_date)"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
ssh banner@stapp03 "sudo chage -l mariyam"
ssh banner@stapp03 "id mariyam"
```

```bash
server="stapp03"
server_user="banner"
username="mariyam"
expected_expiry="apr 15, 2027"

# Check user exists
user_exists=$(ssh "$server_user@$server" \
  "id $username" &>/dev/null && echo "true" || echo "false") && echo "User exists: $user_exists"

# Get account expiry date
actual_expiry=$(ssh "$server_user@$server" \
  "sudo chage -l $username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs) && echo "Expiry: $actual_expiry"

# Validation checks
exists_valid=false
expiry_valid=false

[[ "$user_exists" == "true" ]] && exists_valid=true
[[ "${actual_expiry,,}" == "$expected_expiry" ]] && expiry_valid=true

if [[ "$exists_valid" == true ]] && [[ "$expiry_valid" == true ]]; then
  echo "✓ Success"
  echo "  User: $username"
  echo "  Expiry: $actual_expiry"
else
  echo "✗ Fail"

  if [[ "$exists_valid" == false ]]; then
    echo "  ✗ User does not exist"
    echo "    Expected: $username"
  else
    echo "  ✓ User exists"
  fi

  if [[ "$expiry_valid" == false ]]; then
    echo "  ✗ Expiry date mismatch"
    echo "    Expected: $expected_expiry"
    echo "    Got: $actual_expiry"
  else
    echo "  ✓ Expiry date is correct"
  fi
fi
```

</details>
