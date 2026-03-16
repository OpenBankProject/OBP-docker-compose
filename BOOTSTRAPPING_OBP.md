### Bootstrapping an OBP instance

    cp env.example env

populate postgres_env
 
For Bootstrapping, OBP-OIDC is recommended.

populate the obp_api_env file with

    OBP_DB_URL
    OBP_AUTHUSER_SKIPEMAILVALIDATION=true or configure OBP_MAIL_SMTP_*
    OBP_SUPER_ADMIN_USERNAME=admin
    OBP_SUPER_ADMIN_INITAL_PASSWORD=
    OBP_SUPER_ADMIN_EMAIL=
    OBP_OIDC_OPERATOR_USERNAME=oidc_user
    OBP_OIDC_OPERATOR_INITIAL_PASSWORD=
    OBP_OIDC_OPERATOR_EMAIL=
    OBP_OIDC_OPERATOR_CONSUMER_KEY=Consumer Key
    OBP_OIDC_OPERATOR_CONSUMER_SECRET=Consumer Secret

start services:

    sudo ./manage start

use the `OBP_SUPER_ADMIN_USERNAME` to log in via direct login and grant the `OBP_OIDC_OPERATOR_USERNAME` the entitlements `CanVerifyUserCredentials`, `CanGetOidcClient`, `CanGetConsumers`.


create consumers (Get API Key) for

API Explorer (VITE_OBP_OAUTH2_CLIENT_ID=Consumer Key, VITE_OBP_OAUTH2_CLIENT_SECRET=Consumer Secret)
API Manager (OBP_OAUTH_CLIENT_ID=Consumer Key, OBP_OAUTH_CLIENT_SECRET=Consumer Secret)
API Portal (OBP_OAUTH_CLIENT_ID=Consumer Key, OBP_OAUTH_CLIENT_SECRET=Consumer Secret)


