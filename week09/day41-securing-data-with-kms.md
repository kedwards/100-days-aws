# Day 41: Securing Data with AWS KMS

## Task

The Nautilus DevOps team is focusing on improving their data security by using AWS KMS. Your task is to create a KMS key and manage the encryption and decryption of a pre-existing sensitive file using the KMS key.

Specific Requirements:

    Create a symmetric KMS key named nautilus-KMS-Key to manage encryption and decryption.
    Encrypt the provided SensitiveData.txt file (located in /root/), base64 encode the ciphertext, and save the encrypted version as EncryptedData.bin in the /root/ directory.
    Try to decrypt the same and verify that the decrypted data matches the original file.

Make sure that the KMS key is correctly configured. The validation script will test your configuration by decrypting the EncryptedData.bin file using the KMS key you created.

## Help

```bash
aws kms create-key help
aws kms create-alias help
aws kms describe-key help
aws kms list-aliases help
aws kms encrypt help
aws kms decrypt help
```

<details>
<summary><h2>Solution</h2></summary>

```bash
kms_key_alias=nautilus-KMS-Key
sensitive_file=/root/SensitiveData.txt
encrypted_file=/root/EncryptedData.bin
decrypted_file=/root/DecryptedData.txt

# Create the KMS key
kms_key_id=$(aws kms create-key \
  --description "Nautilus KMS Key for data encryption" \
  --query "KeyMetadata.KeyId" \
  --output text) && echo "KMS Key ID: $kms_key_id"

# Create an alias for the key
aws kms create-alias \
  --alias-name "alias/$kms_key_alias" \
  --target-key-id "$kms_key_id" && echo "Created alias: alias/$kms_key_alias"

# Encrypt the file - KMS returns base64-encoded ciphertext
# Save as binary by decoding the base64 output
aws kms encrypt \
  --key-id "$kms_key_id" \
  --plaintext "fileb://$sensitive_file" \
  --query "CiphertextBlob" \
  --output text | base64 --decode > "$encrypted_file" && echo "Encrypted to: $encrypted_file"

# Decrypt the file to verify
aws kms decrypt \
  --ciphertext-blob "fileb://$encrypted_file" \
  --query "Plaintext" \
  --output text | base64 --decode > "$decrypted_file" && echo "Decrypted to: $decrypted_file"

# Verify decrypted content matches original
if diff -q "$sensitive_file" "$decrypted_file" > /dev/null 2>&1; then
  echo "✓ Decrypted data matches original file"
else
  echo "✗ Decrypted data does NOT match original file"
fi
```

</details>

<details>
<summary><h2>Validate</h2></summary>

```bash
aws kms list-aliases --query "Aliases[?AliasName=='alias/nautilus-KMS-Key']" --output table
aws kms describe-key --key-id alias/nautilus-KMS-Key --output table
ls -la /root/EncryptedData.bin
```

```bash
kms_key_alias=nautilus-kms-key
sensitive_file=./sensitive.txt
encrypted_file=./sensitive.bin

# Check if alias exists
read -r alias_name target_key_id <<< "$(aws kms list-aliases \
  --query "Aliases[?AliasName=='alias/$kms_key_alias'].[AliasName,TargetKeyId]" \
  --output text 2>/dev/null)"&& echo "Alias: $alias_name, Key ID: $target_key_id"

# Check if key is enabled
read -r key_state key_spec <<< "$(aws kms describe-key \
  --key-id "alias/$kms_key_alias" \
  --query "KeyMetadata.[KeyState,KeySpec]" \
  --output text 2>/dev/null)"&& echo "Key State: $key_state, Key Spec: $key_spec"

# Check if encrypted file exists
encrypted_exists=false
[[ -f "$encrypted_file" ]] && encrypted_exists=true && echo "Encrypted file exists: $(ls -la $encrypted_file)"

# Try to decrypt and compare
decrypt_success=false
if [[ "$encrypted_exists" == true ]]; then
  decrypted_content=$(aws kms decrypt \
    --ciphertext-blob "fileb://$encrypted_file" \
    --query "Plaintext" \
    --output text 2>/dev/null | base64 --decode)
  original_content=$(cat "$sensitive_file" 2>/dev/null)
  [[ "$decrypted_content" == "$original_content" ]] && decrypt_success=true
fi

# Validation checks
alias_valid=false
key_enabled=false
file_valid=false

[[ "$alias_name" == "alias/$kms_key_alias" ]] && alias_valid=true
[[ "$key_state" == "Enabled" ]] && key_enabled=true
[[ "$encrypted_exists" == true && "$decrypt_success" == true ]] && file_valid=true

if [[ "$alias_valid" == true ]] && [[ "$key_enabled" == true ]] && [[ "$file_valid" == true ]]; then
  echo "✓ Success"
  echo "  KMS Key Alias: $alias_name"
  echo "  Key ID: $target_key_id"
  echo "  Key State: $key_state"
  echo "  Key Spec: $key_spec (symmetric)"
  echo "  Encrypted file: $encrypted_file"
  echo "  Decryption verified: content matches original"
else
  echo "✗ Fail"
  
  if [[ "$alias_valid" == false ]]; then
    echo "  ✗ KMS key alias not found"
    echo "    Expected: alias/$kms_key_alias"
    echo "    Got: $alias_name"
  else
    echo "  ✓ KMS key alias exists"
  fi
  
  if [[ "$key_enabled" == false ]]; then
    echo "  ✗ KMS key is not enabled"
    echo "    State: $key_state"
  else
    echo "  ✓ KMS key is enabled"
  fi
  
  if [[ "$encrypted_exists" == false ]]; then
    echo "  ✗ Encrypted file not found"
    echo "    Expected: $encrypted_file"
  elif [[ "$decrypt_success" == false ]]; then
    echo "  ✗ Decryption failed or content mismatch"
  else
    echo "  ✓ Encrypted file valid and decryption verified"
  fi
fi
```

</details>
