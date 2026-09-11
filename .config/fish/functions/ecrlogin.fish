function ecrlogin -d "docker login to the ECR registry of an AWS profile's account"
    set -l profile $argv[1]
    set -l region ap-southeast-2
    if test -n "$argv[2]"
        set region $argv[2]
    end
    if test -z "$profile"
        set profile (aws configure list-profiles | fzf --prompt 'aws profile> ')
        or return 1
    end

    set -l account (aws sts get-caller-identity --profile $profile --query Account --output text)
    or return 1

    set -l registry "$account.dkr.ecr.$region.amazonaws.com"
    aws ecr get-login-password --profile $profile --region $region \
        | docker login --username AWS --password-stdin $registry
    or return 1

    echo "ecrlogin: $profile -> $registry"
end
