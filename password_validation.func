#!/bin/bash

validate_password() {
  #This validation:
  #1. Requires minimum length of 8 characters
  #2. Prohibits spaces
  #3. Requires at least one uppercase letter
  #4. Requires at least one lowercase letter
  #5. Requires at least one number
  #6. Requires at least one special character
  
  if [[ $TEST == true ]]; then
    return 0
  fi
  
  local password="$1"
  local min_length=8
  
  # Check minimum length
  if [ ${#password} -lt $min_length ]; then
    msg_error "Password must be at least $min_length characters long"
    return 1
  fi
  
  # Check for spaces
  if [[ "$password" =~ [[:space:]] ]]; then
    msg_error "Password cannot contain spaces"
    return 1
  fi
  
  # Check for at least one uppercase letter
  if ! [[ "$password" =~ [A-Z] ]]; then
    msg_error "Password must contain at least one uppercase letter"
    return 1
  fi
  
  # Check for at least one lowercase letter
  if ! [[ "$password" =~ [a-z] ]]; then
    msg_error "Password must contain at least one lowercase letter"
    return 1
  fi
  
  # Check for at least one number
  if ! [[ "$password" =~ [0-9] ]]; then
    msg_error "Password must contain at least one number"
    return 1
  fi
  
  # Check for at least one special character
  if ! [[ "$password" =~ [[:punct:]] ]]; then
    msg_error "Password must contain at least one special character (!@#$%&*()_+-=[]{};:,.<>?)"
    return 1
  fi
  
  return 0
} 