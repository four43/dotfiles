#!/bin/bash
set -e

function get-ssm() {
    aws ssm get-parameter --name "$1" --with-decryption --output text --query 'Parameter.Value'
}

function write-line() {
    echo "$1" >> ~/.zshenv.secret
}

if [[ -f ~/.zshenv.secret ]]; then
    echo "Not going to overwrite existing ~/.zshenv.secret" >&2
    exit 1
fi


write-line "#!/bin/zsh"
write-line "export AW_SENSU_USERNAME='$(get-ssm "/personal/prod/creds/aerisweather-sensu/username")'"
write-line "export AW_SENSU_PASSWORD='$(get-ssm "/personal/prod/creds/aerisweather-sensu/password")'"

write-line "export AW_BITBUCKET_USERNAME='$(get-ssm "/personal/prod/creds/aerisweather-bitbucket/username")'"
write-line "export AW_BITBUCKET_PASSWORD='$(get-ssm "/personal/prod/creds/aerisweather-bitbucket/password")'"

write-line "export AW_CONFLUENCE_USERNAME='$(get-ssm "/personal/prod/creds/aerisweather-confluence/username")'"
write-line "export AW_CONFLUENCE_PASSWORD='$(get-ssm "/personal/prod/creds/aerisweather-confluence/password")'"

write-line "export OPENAI_API_KEY='$(get-ssm "/personal/prod/creds/openai-chatgpt-api/password")'"

write-line "export AERIS_CLIENT_ID='$(get-ssm "/personal/prod/creds/aerisweather-api-creds/username")'"
write-line "export AERIS_CLIENT_SECRET='$(get-ssm "/personal/prod/creds/aerisweather-api-creds/password")'"
