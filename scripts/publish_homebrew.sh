#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER_SCRIPT="${ROOT_DIR}/packaging/homebrew/render.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/publish_homebrew.sh <tag> <tap_repo> <tap_branch> <tap_formula_path> <rendered_formula_path>

Environment:
  TAP_TOKEN      GitHub token with write access to the tap repository (preferred).
  GITHUB_TOKEN   Fallback token if TAP_TOKEN is unset.
USAGE
}

if [[ $# -ne 5 ]]; then
  usage >&2
  exit 1
fi

TAG="$1"
TAP_REPO="$2"
TAP_BRANCH="$3"
TAP_FORMULA_PATH="$4"
RENDERED_FORMULA="$5"

if [[ -z "${TAG}" ]]; then
  echo "missing release tag" >&2
  exit 1
fi

TOKEN="${TAP_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  echo "Set TAP_TOKEN (or GITHUB_TOKEN) to a GitHub token with write access to ${TAP_REPO}" >&2
  exit 1
fi

if [[ ! -x "${RENDER_SCRIPT}" ]]; then
  echo "missing render script at ${RENDER_SCRIPT}" >&2
  exit 1
fi

mkdir -p "$(dirname "${RENDERED_FORMULA}")"

echo "🧱 Rendering formula for ${TAG}..."
"${RENDER_SCRIPT}" "${TAG}" "${RENDERED_FORMULA}"

tap_dir="$(mktemp -d)"
trap 'rm -rf "'"${tap_dir}"'"' EXIT
repo_url="https://github.com/${TAP_REPO}.git"
auth_header_value=$(printf "x-access-token:%s" "${TOKEN}" | base64 | tr -d '\n')

echo "🔁 Syncing ${TAP_REPO}"
git -c http.extraHeader="Authorization: Basic ${auth_header_value}" clone "${repo_url}" "${tap_dir}"

formula_dest="${tap_dir}/${TAP_FORMULA_PATH}"
mkdir -p "$(dirname "${formula_dest}")"
cp "${RENDERED_FORMULA}" "${formula_dest}"

pushd "${tap_dir}" >/dev/null
if [[ -z "$(git status --porcelain -- "${TAP_FORMULA_PATH}")" ]]; then
  echo "✅ Formula already up to date"
else
  git add "${TAP_FORMULA_PATH}"
  git commit -m "publish(formula): ${TAG}"
  git -c http.extraHeader="Authorization: Basic ${auth_header_value}" push "${repo_url}" "HEAD:${TAP_BRANCH}"
  echo "🚀 Published diffscribe ${TAG} to ${TAP_REPO}"
fi
popd >/dev/null
