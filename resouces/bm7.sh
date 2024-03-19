#!/bin/bash

# 拉取规则文件
if [ ! -d rule ]; then
    git init
    git remote add origin https://github.com/blackmatrix7/ios_rule_script.git
    git config core.sparsecheckout true
    echo "rule/Clash" >> .git/info/sparse-checkout
    git pull --depth 1 origin master
    rm -rf .git
fi

# 移动文件到指定目录
find ./rule/Clash/ -type f -name "*.yaml" -exec mv {} ./rule/Clash/ \;

# 处理规则文件
for yaml_file in ./rule/Clash/*.yaml; do
    base_name=$(basename "$yaml_file" .yaml)

    # 生成针对 Android 包名和进程名的 JSON
    grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_process.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        ./sing-box rule-set compile "${base_name}_process.json" -o "${base_name}_process.srs"
    fi
    rm -f temp.json

    # 生成针对域名的 JSON
    grep -E 'DOMAIN(-SUFFIX|-KEYWORD)?,' "$yaml_file" | grep -v '#' | sed -E 's/  - DOMAIN(-SUFFIX|-KEYWORD)?,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"domain\": [" > "${base_name}_domain.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_domain.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_domain.json"
        ./sing-box rule-set compile "${base_name}_domain.json" -o "${base_name}_domain.srs"
    fi
    rm -f temp.json

    # 生成针对 IP CIDR 的 JSON
    grep 'IP-CIDR,' "$yaml_file" | grep -v '#' | sed 's/  - IP-CIDR,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"ip_cidr\": [" > "${base_name}_ipcidr.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_ipcidr.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_ipcidr.json"
        ./sing-box rule-set compile "${base_name}_ipcidr.json" -o "${base_name}_ipcidr.srs"
    fi
    rm -f temp.json
done
