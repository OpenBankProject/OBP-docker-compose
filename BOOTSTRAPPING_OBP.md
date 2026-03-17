### Bootstrapping an OBP instance

    cp -a env.example env

populate env files. For localhost / non-proxy deployments, make sure to use **service names** as specified in docker-compose.yml ("obp-api", "api-portal", "postgres", "redis", etc.) instead of `localhost` in URLs and hostnames. Adding these hostnames to `/etc/hosts` is also necessary:

    127.0.0.1       obp-oidc obp-portal obp-api api-manager api-explorer keycloak
 
For Bootstrapping, OBP-OIDC is recommended.

update/populate the env files.

    OBP_DB_URL
    OBP_AUTHUSER_SKIPEMAILVALIDATION=true # or configure OBP_MAIL_SMTP_*
    OBP_SUPER_ADMIN_USERNAME=superadmin
    OBP_SUPER_ADMIN_INITAL_PASSWORD=
    OBP_SUPER_ADMIN_EMAIL=
    OBP_OIDC_OPERATOR_USERNAME=oidc_user
    OBP_OIDC_OPERATOR_INITIAL_PASSWORD=
    OBP_OIDC_OPERATOR_EMAIL=
    OBP_OIDC_OPERATOR_CONSUMER_KEY=bevahbaif3zahp3Eexah3ixaesahc1fooC0Seedu
    OBP_OIDC_OPERATOR_CONSUMER_SECRET=Consumer Secret

start services:

    sudo ./manage start

use the `OBP_SUPER_ADMIN_USERNAME` (`superadmin`/`Aing8teze6raeR3pah`) to log in via direct login:

    curl --location --request POST 'http://localhost:8080/my/logins/direct' \
    --header 'Authorization: DirectLogin username="superadmin", password="Aing8teze6raeR3pah", consumer_key=bevahbaif3zahp3Eexah3ixaesahc1fooC0Seedu' \
    --header 'Content-Type: application/json' \
    --data ''

copy the direct login from the response.

get the user_id of oidc_user:

    curl --location 'http://localhost:8080/obp/v6.0.0/users' \
    --header 'Authorization: DirectLogin token=<direct_login_token>'

add these entitlements to the OIDC user (`user_id` of user `oidc_user`):

CanVerifyUserCredentials
CanGetOidcClient
CanGetConsumers
CanGetProviders

    curl --location 'http://localhost:8080/obp/v5.1.0/users/<oidc_user_id>/entitlements' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: DirectLogin token=<direct_login_token>' \
    --data '{  "bank_id":"",  "role_name":"$Entitlement"}'

Create a consumer for OBP Portal:

    curl --location 'http://localhost:8080/obp/v5.1.0/management/consumers' \
    --header 'Content-Type: application/json' \
    --header 'Accept: */*' \
    --header 'Authorization: DirectLogin token=<direct_login_token>' \
    --data-raw '{
    "app_type": "Web",
    "description": "OBP API Portal",
    "enabled": true,
    "redirect_url": "http://api-portal:3000/login/obp/callback",
    "company": "My Company",
    "developer_email": "my@email.com",
    "app_name": "OBP Portal",
    "client_certificate": "",
    "logo_url": ""
    }'

put the response value of `consumer_id` as `OBP_OAUTH_CLIENT_ID` and `consumer_key` as `OBP_OAUTH_CLIENT_SECRET` into api_portal_env.

create consumers (Get API Key) for

API Explorer (VITE_OBP_OAUTH2_CLIENT_ID=Consumer Key, VITE_OBP_OAUTH2_CLIENT_SECRET=Consumer Secret)
API Manager (OBP_OAUTH_CLIENT_ID=Consumer Key, OBP_OAUTH_CLIENT_SECRET=Consumer Secret)
API Portal (OBP_OAUTH_CLIENT_ID=Consumer Key, OBP_OAUTH_CLIENT_SECRET=Consumer Secret)


