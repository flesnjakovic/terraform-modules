resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket

  tags = var.tags
  acl  = var.acl

  dynamic "logging" {
    for_each = length(keys(var.logging)) == 0 ? [] : [var.logging]

    content {
      target_bucket = logging.value.target_bucket
      target_prefix = lookup(logging.value, "target_prefix", null)
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rule

    content {
      id                                     = lookup(lifecycle_rule.value, "id", null)
      prefix                                 = lookup(lifecycle_rule.value, "prefix", null)
      tags                                   = lookup(lifecycle_rule.value, "tags", null)
      abort_incomplete_multipart_upload_days = lookup(lifecycle_rule.value, "abort_incomplete_multipart_upload_days", null)
      enabled                                = lifecycle_rule.value.enabled

      dynamic "expiration" {
        for_each = length(keys(lookup(lifecycle_rule.value, "expiration", {}))) == 0 ? [] : [lookup(lifecycle_rule.value, "expiration", {})]

        content {
          date                         = lookup(expiration.value, "date", null)
          days                         = lookup(expiration.value, "days", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }

      dynamic "transition" {
        for_each = lookup(lifecycle_rule.value, "transition", [])

        content {
          date          = lookup(transition.value, "date", null)
          days          = lookup(transition.value, "days", null)
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = length(keys(lookup(lifecycle_rule.value, "noncurrent_version_expiration", {}))) == 0 ? [] : [lookup(lifecycle_rule.value, "noncurrent_version_expiration", {})]

        content {
          days = lookup(noncurrent_version_expiration.value, "days", null)
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lookup(lifecycle_rule.value, "noncurrent_version_transition", [])

        content {
          days          = lookup(noncurrent_version_transition.value, "days", null)
          storage_class = noncurrent_version_transition.value.storage_class
        }
      }
    }
  }

  dynamic "replication_configuration" {
    for_each = length(keys(var.replication_configuration)) == 0 ? [] : [var.replication_configuration]

    content {
      role = aws_iam_role.replication[0].arn

      dynamic "rules" {
        for_each = replication_configuration.value.rules

        content {
          id       = lookup(rules.value, "id", null)
          priority = lookup(rules.value, "priority", null)
          prefix   = lookup(rules.value, "prefix", null)
          status   = lookup(rules.value, "status", null)

          dynamic "destination" {
            for_each = length(keys(lookup(rules.value, "destination", {}))) == 0 ? [] : [lookup(rules.value, "destination", {})]

            content {
              bucket             = lookup(destination.value, "bucket", null)
              storage_class      = lookup(destination.value, "storage_class", null)
              replica_kms_key_id = lookup(destination.value, "replica_kms_key_id", null)
              account_id         = lookup(destination.value, "account_id", null)

              dynamic "access_control_translation" {
                for_each = length(keys(lookup(destination.value, "access_control_translation", {}))) == 0 ? [] : [lookup(destination.value, "access_control_translation", {})]

                content {
                  owner = access_control_translation.value.owner
                }
              }
            }
          }

          dynamic "source_selection_criteria" {
            for_each = length(keys(lookup(rules.value, "source_selection_criteria", {}))) == 0 ? [] : [lookup(rules.value, "source_selection_criteria", {})]

            content {

              dynamic "sse_kms_encrypted_objects" {
                for_each = length(keys(lookup(source_selection_criteria.value, "sse_kms_encrypted_objects", {}))) == 0 ? [] : [lookup(source_selection_criteria.value, "sse_kms_encrypted_objects", {})]

                content {

                  enabled = sse_kms_encrypted_objects.value.enabled
                }
              }
            }
          }

          dynamic "filter" {
            for_each = length(keys(lookup(rules.value, "filter", {}))) == 0 ? [] : [lookup(rules.value, "filter", {})]

            content {
              prefix = lookup(filter.value, "prefix", null)
              tags   = lookup(filter.value, "tags", null)
            }
          }

        }
      }
    }
  }

  dynamic "versioning" {
    for_each = length(keys(var.versioning)) == 0 ? [] : [var.versioning]

    content {
      enabled    = lookup(versioning.value, "enabled", null)
      mfa_delete = lookup(versioning.value, "mfa_delete", null)
    }
  }

  dynamic "server_side_encryption_configuration" {
    for_each = length(keys(var.server_side_encryption_configuration)) == 0 ? [] : [var.server_side_encryption_configuration]

    content {

      dynamic "rule" {
        for_each = length(keys(lookup(server_side_encryption_configuration.value, "rule", {}))) == 0 ? [] : [lookup(server_side_encryption_configuration.value, "rule", {})]

        content {

          dynamic "apply_server_side_encryption_by_default" {
            for_each = length(keys(lookup(rule.value, "apply_server_side_encryption_by_default", {}))) == 0 ? [] : [
            lookup(rule.value, "apply_server_side_encryption_by_default", {})]

            content {
              sse_algorithm     = apply_server_side_encryption_by_default.value.sse_algorithm
              kms_master_key_id = lookup(apply_server_side_encryption_by_default.value, "kms_master_key_id", null)
            }
          }
        }
      }
    }
  }
}

resource "aws_iam_role" "replication" {
  count = length(keys(var.replication_configuration)) > 0 ? 1 : 0
  name  = "replication-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  count = length(keys(var.replication_configuration)) > 0 ? 1 : 0
  name  = "${aws_s3_bucket.bucket.id}-policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${var.replication_configuration["rules"][0]["destination"]["bucket"]}"
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "replication" {
  count      = length(keys(var.replication_configuration)) > 0 ? 1 : 0
  name       = "bucket-replication-${aws_s3_bucket.bucket.id}"
  roles      = [aws_iam_role.replication[0].name]
  policy_arn = aws_iam_policy.replication[0].arn
}

resource "aws_iam_user" "user" {
  count = var.create_bucket_rw_user == false ? 0 : 1
  name  = "${aws_s3_bucket.bucket.id}-rw-user"
}

resource "aws_iam_policy" "read-write" {
  count  = var.create_bucket_rw_user == false ? 0 : 1
  name   = "rw-policy"
  policy = data.aws_iam_policy_document.read-write.json
}

data "aws_iam_policy_document" "read-write" {
  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "${aws_s3_bucket.bucket.arn}",
    ]
  }

  statement {
    actions = [
      "s3:*Object",
    ]

    resources = [
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

resource "aws_iam_user_policy_attachment" "read-write" {
  count      = var.create_bucket_rw_user == false ? 0 : 1
  user       = aws_iam_user.user[0].name
  policy_arn = aws_iam_policy.read-write[0].arn
}
