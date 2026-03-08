# Day XX - Task title

## Task

Task description goes here. Make sure to include all necessary details and
requirements for the task.

## Help

```bash
command --help
command2 --help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
variable=value

result=$(command \
  --option "$variable") && echo "Result: $result"
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
command --check
```

```bash
expected_value=value

actual_value=$(command \
  --option "$expected_value") && echo "Actual: $actual_value"

valid=false

[[ "$actual_value" == "$expected_value" ]] && valid=true

if [[ "$valid" == true ]]; then
  echo "✓ Success"
  echo "  Value: $actual_value"
else
  echo "✗ Fail"
  
  if [[ "$valid" == false ]]; then
    echo "  ✗ Validation failed"
    echo "    Expected: $expected_value"
    echo "    Got: $actual_value"
  else
    echo "  ✓ Validation passed"
  fi
fi
```

</details>
