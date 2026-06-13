#!/usr/bin/env bash
# Empty an S3 bucket (delete all objects, including versions + delete markers) so it
# can be deleted.
#
# WHY THIS EXISTS: ACK's S3 controller calls the AWS DeleteBucket API directly and has
# NO force-destroy mechanism — no spec field, no annotation, no pre-delete hook (verified
# against aws-controllers-k8s/s3-controller). That is unlike the other two tracks, which
# empty on teardown declaratively: Crossplane's composition sets `forceDestroy: true`, and
# KCC's StorageBucket carries the `cnrm.cloud.google.com/force-destroy: "true"` annotation.
# So on the ACK track a non-empty bucket blocks teardown ("...containing objects without
# force_destroy set to true"); empty it with this helper FIRST, then delete the CR/Application.
#
# Source this file; do not execute it.

# Fallbacks so this works whether or not common.sh is already sourced.
if ! command -v print_success >/dev/null 2>&1; then
    print_step()    { printf '\n== %s ==\n' "$1"; }
    print_success() { printf '✓ %s\n' "$1"; }
    print_warning() { printf '⚠ %s\n' "$1"; }
    print_error()   { printf '✗ %s\n' "$1" >&2; }
fi

# empty_s3_bucket <bucket_name>
#
# Deletes every object in the bucket. Reads AWS credentials from the environment
# (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY [/ AWS_SESSION_TOKEN] — exported by
# load_aws_env); the aws CLI picks them up automatically. Requires the aws CLI.
# No-op (returns 0) if the bucket does not exist or is not accessible.
empty_s3_bucket() {
    local bucket="$1"
    if [ -z "$bucket" ]; then
        print_error "empty_s3_bucket: bucket name required"
        return 1
    fi
    if ! command -v aws >/dev/null 2>&1; then
        print_error "aws CLI is required to empty S3 buckets (not found on PATH)"
        return 1
    fi
    if ! aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
        print_warning "Bucket '$bucket' not found or not accessible — skipping"
        return 0
    fi

    print_warning "Emptying s3://$bucket ..."

    # 1) Current objects — enough for non-versioned / versioning-suspended buckets
    #    (the demo default, since the `bucket` claim's versioning defaults to false).
    aws s3 rm "s3://$bucket" --recursive || true

    # 2) Object versions + delete markers — only present if versioning was ever Enabled.
    #    Build the delete payload with --query (no jq dependency); skip when empty.
    local versions markers
    versions="$(aws s3api list-object-versions --bucket "$bucket" \
        --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || true)"
    if printf '%s' "$versions" | grep -q '"Key"'; then
        aws s3api delete-objects --bucket "$bucket" --delete "$versions" >/dev/null 2>&1 || true
    fi
    markers="$(aws s3api list-object-versions --bucket "$bucket" \
        --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || true)"
    if printf '%s' "$markers" | grep -q '"Key"'; then
        aws s3api delete-objects --bucket "$bucket" --delete "$markers" >/dev/null 2>&1 || true
    fi

    print_success "Emptied s3://$bucket"
}
