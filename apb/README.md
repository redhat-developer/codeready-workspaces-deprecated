# Code Ready Workspaces APB

## How to Build

```
docker build -t 172.30.1.1:5000/openshift/codeready-apb .
```

You can use any image name and tag. It depends on your OpenShift setup. For MiniShift and a local Origin,
you may use this image name (which is a default one for the installer script). For OCP, OSD, you need to build the image with whatever name, tag it and push it to your OpenShift local registry, openshift namespace (requires cluster admin privileges).

When on MiniShift, before building the image, make sure you local Docker is connected to MiniShift's docker daemon:

```
eval $(minishift docker-env)
```

This way, the resulting image will be available fro Docker in a MiniShift VM.

## How to run

### Pre-reqs

* a running OpenShift instance
* an active session (you should be logged in)
* **OPTIONAL** Only if you enable Login with OpenShift (`-oauth, --enable-oauth`): current user must have cluster-admin privileges.

### Installation Modes

#### Internactive

`-i, --interactive`

When activated, you will be asked questions about your Code Ready Workspaces installation

#### Fast

`-f, --fast` Recommended mode

When in a fact mode, the installer script will use command line args and `config.json` file to populate APB extra vars.

#### Configuration

Overriding default envs are available in fast mode only. Not all configuration parameters are available as flags. Run `./deploy.sh --help` to get a list of all available arguments.

`config.json` contains default values for installation params. Those params that take environment variables as values can be overridden from a command line. Before running the script in a fast mode, review `config.json`.


```
"che_image_name": "${SERVER_IMAGE_NAME}",             // defaults to eclipse/che-server
"che_image_tag": "${SERVER_IMAGE_TAG}",               // defaults to nightly
"che_secure_routes": false,                           // https support in Che. Keep it false if you are on a local Origin with self signed certs
"che_external_db": false,                             // Set to true, if you want to connect to an external db, and skip deploying Postgres instance
"che_jdbc_db_host": "postgres",                       // Database hostname. Do not change, unless you want to connect to an external DB
"che_jdbc_db_port": "5432",                           // Postgres port. Do not change unless a remote DB runs on a non default port
"che_jdbc_db_name": "dbcodeready",                    // Database name
"che_jdbc_username": "pgcodeready",                   // Database user. MUST be a SUPERUSER
"che_jdbc_password": "pgcodereadypassword",           // Database password
"external_keycloak": false,                           // Set to true if you want to connect to an existing Red Hat SSO/Keycloak instance
"external_keycloak_uri":"",                           // Provide Red hat SSO URL. No trailing /auth. Just protocol and hostname
"keycloak_provision_realm_user": true,                // Keep unchanged unless you want to use an existing realm and client (must be public)
"che_keycloak_admin_username": "admin",               // Red Hat SSO admin name
"che_keycloak_admin_password": "admin",               // Red Hat SSO admin password
"namespace": "${OPENSHIFT_PROJECT}",                  // Leave as is. Defaults to current namespace
"che_keycloak_realm": "codeready",                    // Red Hat SSO realm
"che_keycloak_client__id": "codeready-public",        // Red Hat SSO client
"use_self_signed_cert": false,                        // Add self signed certs to truststore of server and Red Hat SSO. If enabled, provide path to cert file - -c=/path/to/file
"enable_openshift_oauth": "${ENABLE_OPENSHIFT_OAUTH}",// Enable Login with OpenShift. Requires cluster-admin privileges. Enable self signed certs if your cluster uses them
"openshift_api_uri": "${OPENSHIFT_API_URI}"           // Only when OpenShift oAuth is enabled. Provide OpenShift API URI, for example https://api.mycluster.com
```

#### Examples

##### Fast mode with all defaults

The following command will grab config from config.json and start an installer image:

```
./deploy.sh -f
```
Specify a namespace:

```
./deploy.sh -f -p=mynamespace
```

#### Fast mode with support of self signed certs, OpenShift oAuth and a custom server-image

```
./deploy.sh -f -c=/var/lib/origin/openshift.local.config/master/ca.crt -oauth -api=https://172.19.20.126:8443 --server-image=myserver/image
```

##### Fast mode with external Red Hat SSO and enabled realm provisioning:

In `config.json`:

```
"external_keycloak": true,                         
"external_keycloak_uri":"https://my-rh-sso.com",
"keycloak_provision_realm_user": true,
```

##### Fast mode with external Red Hat SSO and Postgres DB:

```
"che_external_db": true,
"che_jdbc_db_host": "114.54.123.40",
"che_jdbc_db_port": "5432",
"che_jdbc_db_name": "mydatabase",
"che_jdbc_username": "mysuperuser",
"che_jdbc_password": "mypassword",

....

"external_keycloak": true,                         
"external_keycloak_uri":"https://my-rh-sso.com",
"keycloak_provision_realm_user": true,
```

##### Interactive mode

```
./deploy.sh -i
```
To specify a namespace

```
./deploy.sh -i
```

##### Interactive mode with self signed certs and OpenShift oAuth

```
./deploy.sh -i -oauth -c=/path/to/cert.ca
```
