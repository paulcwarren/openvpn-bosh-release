def create_dev_release:
  [
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
    }
  ]
;

def run_integration_tests:
  {
    "do": [
      {
        "aggregate": [
          {
            "get": "bosh-lite-stemcell"
          },
          {
            "put": "bosh-lite"
          }
        ]
      },
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
;

def docker_ci_image($name; $branch):
  {
    "name": ("ci-" + $name + "-image"),
    "type": "docker-image",
    "source": {
      "repository": .docker.repository,
      "tag": ("ci-" + $name + "-" + $branch),
      "insecure_registries": .docker.insecure_registries,
      "email": .docker.email,
      "username": .docker.username,
      "password": .docker.password
    }
  }
;

def normalize_pipeline:
  . as $p
  | $p + { "groups": ( [ { "name": "all", "jobs": ( $p.jobs | map(.name) ) } ] + $p.groups ) }
  | to_entries | map({ key, "value": (if "groups" == .key then .value else .value | sort_by(.name) end) }) | sort_by(.key) | from_entries
;
