#!/bin/bash

# 定义规则文件的存放目录
rule_dir="rule/Clash"

# 如果目录不存在，则创建目录
if [ ! -d "$rule_dir" ]; then
    mkdir -p "$rule_dir"
fi

# 定义需要下载的规则文件链接
declare -a urls=(
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Apple/Apple_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Proxy/Proxy_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Global/Global_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/GlobalMedia/GlobalMedia_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Classical.yaml"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Clash/Rule/OpenAI.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Microsoft/Microsoft.yaml"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Loon/Rule/TelegramALL.list"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Loon/Rule/TelegramUS.list"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Gemini/Gemini.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Claude/Claude.yaml"
)

# 下载规则文件
for url in "${urls[@]}"; do
    filename=$(basename "$url")
    # 使用curl命令下载文件
    curl -L "$url" -o "${rule_dir}/${filename}"
done

# 初始化临时文件，用于收集JSON规则
temp_json="temp_rules.json"

# 处理规则文件
for yaml_file in "$rule_dir"/*.yaml; do
    base_name=$(basename "$yaml_file" .yaml)
    
    # 检查文件是否含有域名相关规则
    if grep -qE 'DOMAIN(-SUFFIX|-KEYWORD)?,|DOMAIN,' "$yaml_file"; then
        # 初始化JSON文件内容
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\n      \"domain_suffix\": [],\n      \"domain_keyword\": [],\n      \"domain\": []\n    }\n  ]\n}" > "${base_name}_domain.json"
        
        # 使用jq仅一次处理所有规则
        jq --argfile rules <(grep -E 'DOMAIN(-SUFFIX|-KEYWORD)?,|DOMAIN,' "$yaml_file" | \
          awk -F, '/DOMAIN-SUFFIX/{print "\"domain_suffix\": \"" $2 "\""}
                   /DOMAIN-KEYWORD/{print "\"domain_keyword\": \"" $2 "\""}
                   /DOMAIN,/{print "\"domain\": \"" $2 "\""}' | \
          jq -s -R 'split("\n")[:-1] | map(split(": ")) | map({(.[0]): .[1]}) | add' | \
          jq '{version: 1, rules: [.]}') "${base_name}_domain.json" > "$temp_json" && mv "$temp_json" "${base_name}_domain.json"
    fi

    # 生成针对 Android 包名和进程名的 JSON
    grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_process.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        ./sing-box rule-set compile "${base_name}_process.json" -o "${base_name}_process.srs"
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
