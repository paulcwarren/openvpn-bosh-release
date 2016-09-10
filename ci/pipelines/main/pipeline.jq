include "shared" {"search":".."};

{
  "groups": [
    {
      "name": "meta",
      "jobs": [
        "ci-bosh-image"
      ]
    }
  ],
  "jobs": [
    {
      "name": "ci-bosh-image",
      "serial": true,
      "plan": [
        {
          "get": "images-repo",
          "trigger": true
        },
        {
          "put": "ci-bosh-image",
          "params": {
            "build": "images-repo/ci/images/bosh"
          },
          "get_params": {
            "skip_download": true
          }
        }
      ]
    },
    {
      "name": "create-develop-release",
      "serial_groups": [
        "version"
      ],
      "plan": ([
        {
          "get": "repo",
          "resource": "develop-repo",
          "trigger": true
        },
        create_dev_release,
        {
          "put": "develop-release",
          "params": {
            "file": "release/*.tgz"
          }
        }
      ]|flatten)
    },
    {
      "name": "test-develop-integration",
      "serial": true,
      "plan": [
        {
          "aggregate": [
            {
              "get": "release",
              "resource": "develop-release",
              "trigger": true,
              "passed": [
                "create-develop-release"
              ]
            },
            {
              "get": "repo",
              "resource": "develop-repo",
              "passed": [
                "create-develop-release"
              ]
            }
          ]
        },
        {
          "put": "integration-github-status",
          "params": {
            "commit": "repo",
            "state": "pending"
          }
        },
        {
          "do": [
            run_integration_tests
          ],
          "on_success": {
            "put": "integration-github-status",
            "params": {
              "commit": "repo",
              "state": "success"
            }
          },
          "on_failure": {
            "put": "integration-github-status",
            "params": {
              "commit": "repo",
              "state": "failure"
            }
          }
        }
      ]
    },
    {
      "name": "promote-candidate",
      "serial": true,
      "plan": [
        {
          "aggregate": [
            {
              "get": "release",
              "resource": "develop-release",
              "trigger": true,
              "passed": [
                "test-develop-integration"
              ]
            },
            {
              "get": "repo",
              "resource": "develop-repo",
              "passed": [
                "test-develop-integration"
              ]
            }
          ]
        },
        {
          "aggregate": [
            {
              "put": "candidate-repo",
              "params": {
                "repository": "repo"
              }
            },
            {
              "put": "candidate-release",
              "params": {
                "file": "release/*.tgz"
              }
            }
          ]
        }
      ]
    },
    {
      "name": "shipit",
      "serial_groups": [
        "version"
      ],
      "plan": [
        {
          "aggregate": [
            {
              "get": "candidate-release",
              "passed": [
                "promote-candidate"
              ]
            },
            {
              "get": "candidate-repo",
              "passed": [
                "promote-candidate"
              ]
            },
            {
              "get": "version",
              "params": {
                "bump": "final"
              }
            },
            {
              "get": "develop-repo"
            },
            {
              "get": "master-repo"
            }
          ]
        },
        {
          "task": "finalize-release",
          "file": "candidate-repo/ci/tasks/finalize-release/task.yml",
          "params": {
            "blobstore_s3_access_key_id": .blobstore.access_key_id,
            "blobstore_s3_secret_access_key": .blobstore.secret_access_key,
            "git_user_email": .bot.email,
            "git_user_name": .bot.name
          }
        },
        {
          "put": "version",
          "params": {
            "file": "version/number"
          }
        },
        {
          "put": "master-repo",
          "params": {
            "repository": "master-repo"
          }
        },
        {
          "put": "develop-repo",
          "params": {
            "repository": "develop-repo"
          }
        },
        {
          "put": "master-release",
          "params": {
            "file": "master-release-artifacts/*.tgz"
          }
        },
        {
          "put": "master-github-release",
          "params": {
            "name": "master-release-artifacts/name",
            "tag": "master-release-artifacts/name",
            "commitish": "master-release-artifacts/commit",
            "body": "master-release-artifacts/notes.md"
          }
        }
      ]
    },

    #
    # allow manual major and minor version bumps
    #

    {
      "name": "bump-major",
      "serial_groups": [
        "version"
      ],
      "plan": [
        {
          "get": "version",
          "params": {
            "bump": "major",
            "pre": "dev"
          }
        },
        {
          "put": "version",
          "params": {
            "file": "version/number"
          }
        }
      ]
    },
    {
      "name": "bump-minor",
      "serial_groups": [
        "version"
      ],
      "plan": [
        {
          "get": "version",
          "params": {
            "bump": "minor",
            "pre": "dev"
          }
        },
        {
          "put": "version",
          "params": {
            "file": "version/number"
          }
        }
      ]
    },

    #
    # whenever we release, automatically bump the patch version
    #

    {
      "name": "bump-patch",
      "serial_groups": [
        "version"
      ],
      "plan": [
        {
          "get": "version",
          "passed": [
            "shipit"
          ],
          "trigger": true,
          "params": {
            "bump": "patch",
            "pre": "dev"
          }
        },
        {
          "put": "version",
          "params": {
            "file": "version/number"
          }
        }
      ]
    }
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

    #
    # develop - where the action happens
    #

    {
      "name": "develop-repo",
      "type": "git",
      "source": {
        "uri": .repository.uri,
        "branch": .repository_branches.develop,
        "private_key": .repository.private_key
      }
    },
    {
      "name": "develop-release",
      "type": "s3",
      "source": {
        "bucket": .blobstore.bucket,
        "regexp": "develop/release/openvpn-(.*).tgz",
        "access_key_id": .blobstore.access_key_id,
        "secret_access_key": .blobstore.secret_access_key
      }
    },
    {
      "name": "integration-github-status",
      "type": "github-status",
      "source": {
        "repository": (.repository.github.owner + "/" + .repository.github.repository),
        "access_token": .repository.github.access_token,
        "branch": .repository_branches.develop,
        "context": "ci/integration"
      }
    },

    #
    # candidate - when we have happy code
    #

    {
      "name": "candidate-repo",
      "type": "git",
      "source": {
        "uri": .repository.uri,
        "branch": .repository_branches.candidate,
        "private_key": .repository.private_key
      }
    },
    {
      "name": "candidate-release",
      "type": "s3",
      "source": {
        "bucket": .blobstore.bucket,
        "regexp": "rc/release/openvpn-(.*).tgz",
        "access_key_id": .blobstore.access_key_id,
        "secret_access_key": .blobstore.secret_access_key
      }
    },

    #
    # master - when we have production code
    #

    {
      "name": "master-repo",
      "type": "git",
      "source": {
        "uri": .repository.uri,
        "branch": .repository_branches.master,
        "private_key": .repository.private_key
      }
    },
    {
      "name": "master-release",
      "type": "s3",
      "source": {
        "bucket": .blobstore.bucket,
        "regexp": "master/release/openvpn-(.*).tgz",
        "access_key_id": .blobstore.access_key_id,
        "secret_access_key": .blobstore.secret_access_key
      }
    },
    {
      "name": "master-github-release",
      "type": "github-release",
      "source": {
        "user": .repository.github.owner,
        "repository": .repository.github.repository,
        "access_token": .repository.github.access_token
      }
    },

    #
    # bosh-lite provisioning for test environments
    #

    {
      "name": "bosh-lite",
      "type": "aws-bosh-lite",
      "source": {
        "access_key": .bosh_lite.access_key_id,
        "availability_zone": .bosh_lite.availability_zone,
        "name": .bosh_lite.name,
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
    # images
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
          "ci/images/**/*"
        ]
      }
    },
    docker_ci_image("bosh"; .repository_branches.develop)
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
    {
      "name": "github-status",
      "type": "docker-image",
      "source": {
        "repository": "dpb587/github-status-resource",
        "tag": "master"
      }
    }
  ]
}
| normalize_pipeline
