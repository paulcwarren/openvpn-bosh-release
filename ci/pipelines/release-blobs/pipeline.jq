include "shared" {"search":".."};

. as $config |
{
  "groups": [
    {
      "name": "bumps",
      "jobs": (.release_blobs | map("bump-" + .))
    },
    {
      "name": "meta",
      "jobs": (.release_blobs | map("ci-release-blob-" + . + "-image"))
    }
  ],
  "jobs": [
    (.release_blobs | map({
      "name": ("ci-release-blob-" + . + "-image"),
      "serial": true,
      "plan": [
        {
          "get": "repo",
          "resource": "images-repo",
          "trigger": true
        },
        {
          "task": "prepare-buildroot",
          "file": "repo/ci/images/release-blob/prepare/task.yml",
          "params": {
            "blob": .
          }
        },
        {
          "put": ("ci-release-blob-" + . + "-image"),
          "params": {
            "build": "buildroot"
          },
          "get_params": {
            "skip_download": true
          }
        }
      ]
    })[]),
    (.release_blobs | map(. as $blob | $config | {
      "name": ("bump-" + $blob),
      "serial": true,
      "serial_groups": [
        "bosh-lite"
      ],
      "plan": [
        {
          "aggregate": [
            {
              "get": "blob",
              "resource": ("release-blob-" + $blob),
              "trigger": true
            },
            {
              "get": "image",
              "resource": ("ci-release-blob-" + $blob + "-image"),
              "params": {
                "skip_download": true
              },
              "trigger": true,
              "passed": [
                "ci-release-blob-" + $blob + "-image"
              ]
            }
          ]
        },
        {
          "get": "repo"
        },
        {
          "task": "bump-release-blob",
          "file": "repo/ci/tasks/bump-release-blob/task.yml",
          "params": {
            "blob": $blob
          }
        },
        create_dev_release[],
        run_integration_tests,
        {
          "task": "finalize-release-blob",
          "file": "repo/ci/tasks/finalize-release-blob/task.yml",
          "params": {
            "blob": $blob,
            "blobstore_s3_access_key_id": .blobstore.access_key_id,
            "blobstore_s3_secret_access_key": .blobstore.secret_access_key,
            "git_user_email": .bot.email,
            "git_user_name": .bot.name
          }
        },
        {
          "task": "send-pull-request",
          "file": "repo/ci/tasks/send-release-blob-pr/task.yml",
          "params": {
            "blob": $blob,
            "branch": ("bump-" + $blob),
            "base_branch": .repository_branches.develop,
            "access_token": .repository.github.access_token,
            "private_key": .repository.private_key,
            "owner": .repository.github.owner,
            "repository": .repository.github.repository
          }
        }
      ]
    })[])
  ],
  "resources": [
    {
      "name": "version",
      "type": "semver",
      "source": {
        "bucket": .blobstore.bucket,
        "key": "version",
        "access_key_id": .blobstore.access_key_id,
        "secret_access_key": .blobstore.secret_access_key
      }
    },

    {
      "name": "repo",
      "type": "git",
      "source": {
        "uri": .repository.uri,
        "branch": .repository_branches.develop,
        "private_key": .repository.private_key
      }
    },

    (
      .release_blobs | map({
        "name": ("release-blob-" + .),
        "type": ("release-blob-" + .),
        "check_every": "24h"
      })[]
    ),

    #
    # bosh-lite provisioning for test environments
    #

    {
      "name": "bosh-lite",
      "type": "aws-bosh-lite",
      "source": {
        "access_key": .bosh_lite.access_key_id,
        "availability_zone": .bosh_lite.availability_zone,
        "name": (.bosh_lite.name + "-release-blobs"),
        "instance_type": .bosh_lite.instance_type,
        "key_name": .bosh_lite.key_name,
        "private_ip": .bosh_lite.private_ip,
        "secret_key": .bosh_lite.secret_key,
        "security_group_id": .bosh_lite.security_group_id,
        "subnet_id": .bosh_lite.subnet_id
      }
    },
    {
      "name": "bosh-lite-integration-deployment",
      "type": "bosh-deployment",
      "source": {
        "username": "admin",
        "password": "admin",
        "deployment": "integration-test"
      }
    },
    {
      "name": "bosh-lite-stemcell",
      "type": "bosh-io-stemcell",
      "source": {
        "name": "bosh-warden-boshlite-ubuntu-trusty-go_agent"
      }
    },

    #
    # for building images
    #

    {
      "name": "images-repo",
      "type": "git",
      "source": {
        "uri": .repository.uri,
        "branch": .repository_branches.develop,
        "private_key": .repository.private_key,
        "paths": [
          "ci/images/*",
          "ci/images/**/*",
          "src/blobs/*",
          "src/blobs/**/*"
        ]
      }
    },
    (.release_blobs | map( . as $blob | $config | docker_ci_image("release-blob-" + $blob; .repository_branches.develop) )[])
  ],
  "resource_types": [
    {
      "name": "aws-bosh-lite",
      "type": "docker-image",
      "source": {
        "repository": "dpb587/aws-bosh-lite-resource",
        "tag": "master"
      }
    },
    (
      .release_blobs | map( . as $blob | $config |
        {
          "name": ("release-blob-" + $blob),
          "type": "docker-image",
          "source": {
            "repository": .docker.repository,
            "tag": ("ci-release-blob-" + $blob + "-" + .repository_branches.develop),
            "insecure_registries": .docker.insecure_registries
          }
        }
      )[]
    )
  ]
}
| normalize_pipeline
