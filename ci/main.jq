{
  "jobs": [
    {
      "name": "create-develop-release",
      "serial_groups": [
        "version"
      ],
      "plan": [
        {
          "get": "repo",
          "resource": "develop-repo",
          "trigger": true
        },
        {
          "get": "version",
          "params": {
            "pre": "dev"
          }
        },
        {
          "put": "version",
          "params": {
            "file": "version/number"
          }
        },
        {
          "task": "create-release",
          "file": "repo/ci/tasks/create-release/task.yml"
        },
        {
          "put": "develop-release",
          "params": {
            "file": "create-release/*.tgz"
          }
        }
      ]
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
          "get": "bosh-lite-stemcell"
        },
        {
          "put": "integration-github-status",
          "params": {
            "commit": "repo",
            "state": "pending"
          }
        },
        {
          "put": "bosh-lite"
        },
        {
          "do": [
            {
              "put": "bosh-lite-integration-deployment",
              "params": {
                "target_file": "bosh-lite/target",
                "manifest": "repo/ci/tasks/integration-test/deployment.yml",
                "stemcells": [
                  "bosh-lite-stemcell/*.tgz"
                ],
                "releases": [
                  "release/*.tgz"
                ]
              }
            },
            {
              "task": "integration-test",
              "file": "repo/ci/tasks/integration-test/task.yml"
            }
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
          },
          "ensure": {
            "put": "bosh-lite",
            "params": {
              "delete": true
            },
            "get_params": {
              "allow_deleted": true
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
            "blobstore_s3_access_key_id": $config.blobstore.access_key_id,
            "blobstore_s3_secret_access_key": $config.blobstore.secret_access_key,
            "git_user_email": $config.user.email,
            "git_user_name": $config.user.name
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
      "name": "develop-repo",
      "type": "git",
      "source": {
        "uri": $config.repository.uri,
        "branch": $config.repository.develop_branch,
        "private_key": $config.repository.private_key
      }
    },
    {
      "name": "develop-release",
      "type": "s3",
      "source": {
        "bucket": $config.blobstore.bucket,
        "regexp": "develop/release/openvpn-(.*).tgz",
        "access_key_id": $config.blobstore.access_key_id,
        "secret_access_key": $config.blobstore.secret_access_key
      }
    },
    {
      "name": "version",
      "type": "semver",
      "source": {
        "bucket": $config.blobstore.bucket,
        "key": "version",
        "access_key_id": $config.blobstore.access_key_id,
        "secret_access_key": $config.blobstore.secret_access_key
      }
    },
    {
      "name": "candidate-repo",
      "type": "git",
      "source": {
        "uri": $config.repository.uri,
        "branch": $config.repository.candidate_branch,
        "private_key": $config.repository.private_key
      }
    },
    {
      "name": "candidate-release",
      "type": "s3",
      "source": {
        "bucket": $config.blobstore.bucket,
        "regexp": "rc/release/openvpn-(.*).tgz",
        "access_key_id": $config.blobstore.access_key_id,
        "secret_access_key": $config.blobstore.secret_access_key
      }
    },
    {
      "name": "master-repo",
      "type": "git",
      "source": {
        "uri": $config.repository.uri,
        "branch": $config.repository.master_branch,
        "private_key": $config.repository.private_key
      }
    },
    {
      "name": "master-release",
      "type": "s3",
      "source": {
        "bucket": $config.blobstore.bucket,
        "regexp": "master/release/openvpn-(.*).tgz",
        "access_key_id": $config.blobstore.access_key_id,
        "secret_access_key": $config.blobstore.secret_access_key
      }
    },
    {
      "name": "bosh-lite",
      "type": "aws-bosh-lite",
      "source": {
        "access_key": $config.bosh_lite.access_key_id,
        "availability_zone": $config.bosh_lite.availability_zone,
        "name": $config.bosh_lite.name,
        "instance_type": $config.bosh_lite.instance_type,
        "key_name": $config.bosh_lite.key_name,
        "private_ip": $config.bosh_lite.private_ip,
        "secret_key": $config.bosh_lite.secret_key,
        "security_group_id": $config.bosh_lite.security_group_id,
        "subnet_id": $config.bosh_lite.subnet_id
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
    {
      "name": "master-github-release",
      "type": "github-release",
      "source": {
        "user": $config.github.user,
        "repository": $config.github.repository,
        "access_token": $config.github.access_token
      }
    },
    {
      "name": "integration-github-status",
      "type": "github-status",
      "source": {
        "repository": ($config.github.user + "/" + $config.github.repository),
        "access_token": $config.github.access_token,
        "branch": $config.repository.develop_branch,
        "context": "ci/integration"
      }
    }
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
