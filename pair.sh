#!/usr/bin/env bash

[[ -f "$HOME/.pairrc" ]] && source "$HOME/.pairrc"

function pair {

local pair_file="$HOME/.pairrc"


# STATIC TEXT =================================================================

local generated_heading="\
# This file is automatically generated by the pair() function found in ~/.pair"

local usage_short="\
pair --help
pair --unpair
pair [--domain <domain>] [--prefix <prefix>] username1 [username2...]"

local err_no_users="\
\033[0;31mERROR:\033[0m no Github usernames were supplied; usage:
$usage_short"



# HELPER FUNCTIONS ============================================================

function _pair_show_usage_long {
  cat <<USAGE | less
pair - Git author pairing
=========================

A convenient script for setting the current Git repository's user.name and
user.email to the collective Github names and emails of the listed
participants.

IMPORTANT: This requires that the user source the ".pairrc" file in their home
directory.

Usage
-----

$1

Arguments
---------

pair
  Display the current pair information.

username1 [username2...]
  Sets the following environment variables:

  - GIT_AUTHOR_NAME and GIT_COMMITTER_NAME to
    "<username1's name> + <username2's name>"

  - GIT_AUTHOR_EMAIL and GIT_COMMITTER_EMAIL to
    "<PAIR_EMAIL_PREFIX>+username1+username2@<PAIR_EMAIL_DOMAIN>"

  If only a single username is supplied, then their Github name and email will
  be used in the Git settings.

-d (--domain)
  Sets the domain of "user.email" to the given domain. The domain is not
  checked for accuracy; this is left to the user.

-h (--help)
  Displays this help text.

-p (--prefix)
  Sets the prefix (everything before the email comments containing the
  usernames) of "user.email" to the given prefix.

-u (--unpair)
  Sets "user.name" and "user.email" as blank.

USAGE
}

function _pair_err_invalid_option {
  echo -e "\033[0;31mERROR:\033[0m invalid option \"$1\"; usage:
$usage_short"
  return 1
}

function _pair_err_missing_arg {
  echo -e "\033[0;31mERROR:\033[0m missing argument to option \"$1\"; usage:
$usage_short"
  return 1
}

function _pair_unset {
  cat <<UNPAIR > "$pair_file"
$generated_heading

unset GIT_AUTHOR_NAME
unset GIT_AUTHOR_EMAIL
unset GIT_COMMITTER_NAME
unset GIT_COMMITTER_EMAIL
UNPAIR
}

function _pair_set {
  cat <<PAIR > "$pair_file"
$generated_heading

export GIT_AUTHOR_NAME="$1"
export GIT_AUTHOR_EMAIL="$2"
export GIT_COMMITTER_NAME="$1"
export GIT_COMMITTER_EMAIL="$2"
PAIR
}

function _pair_name_for {
  echo "$(curl -is https://api.github.com/users/$1 | \
    grep -o '"name":.*"' | \
    cut -d \" -f 4)"
}

function _pair_warn_no_github_name {
  echo -e "\033[0;33mWARNING:\033[0m No Github name found for user \"$1\""
}



# SCRIPT ======================================================================

local opt_email_domain opt_email_prefix opt_unpair  # function options
local domain name prefix users                      # used in for loops
local pair_email pair_name usernames                # crafting the pair values



# Parse options and arguments, including getting the list of usernames to pair

while [ $# -gt 0 ] ; do
  case "$1" in
    '-h' | '--help'   ) _pair_show_usage_long "$usage_short"                         ; return 0 ;;

    '-u' | '--unpair' ) opt_unpair="true"                                            ; break    ;;

    '-d' | '--domain' ) if [[ -n "$2" ]] ; then
                          opt_email_domain=$2
                        else
                          echo -e "$(_pair_err_missing_arg "$1")"
                          return 1
                        fi                                                           ; shift 2  ;;

    '-p' | '--prefix' ) if [[ -n "$2" ]] ; then
                          opt_email_prefix=$2
                        else
                          echo -e "$(_pair_err_missing_arg "$1")"
                          return 1
                        fi                                                           ; shift 2  ;;

    -*                ) echo -e "$(_pair_err_invalid_option "$1")" >&2               ; return 1 ;;

    *                 ) if [[ -n $usernames ]] ; then
                          usernames="$usernames\n$1"
                        else
                          usernames="$1"
                        fi                                                           ; shift 1 ;;
  esac
done



# Unset the Git config vars if unpairing

if [[ -n "$opt_unpair" ]]; then
  _pair_unset
  pair_name="$(git config user.name)"
  pair_email="$(git config user.email)"
else



  # Error if no usernames are supplied

  if [[ -z "$usernames" ]]; then
    echo -e "$err_no_users"
    return 1
  fi



  # Generate the pairing name

  for user in $(echo -e "$usernames" | sort); do
    name="$(_pair_name_for "$user")"

    if [[ -z "$name" ]] ; then
      echo -e "$(_pair_warn_no_github_name "$user")"
      name="$user"
    fi

    [[ -n "$pair_name" ]] && name=" + $name" || name="$name"
    pair_name="$pair_name$name"
  done



  # Generate the pairing email address

  for prefix in 'dev' "$PAIR_EMAIL_PREFIX" "$opt_email_prefix"; do
    [[ -n "$prefix" ]] && email_prefix="$prefix"
  done

  for domain in 'bendyworks.com' "$PAIR_EMAIL_DOMAIN" "$opt_email_domain"; do
    [[ -n "$domain" ]] && email_domain="$domain"
  done

  pair_email="$email_prefix"
  for user in $(echo -e "$usernames" | sort); do
    pair_email="$pair_email+$user"
  done
  pair_email="$pair_email@$email_domain"



  # Export the pair names as config vars

  _pair_set "$pair_name" "$pair_email"
fi



# SUCCESS =====================================================================

. "$pair_file"
echo -e "New pair is: $pair_name <$pair_email>"
return 0
}
