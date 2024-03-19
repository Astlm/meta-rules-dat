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

# 处理规则文件
for yaml_file in "$rule_dir"/*.yaml; do
    base_name=$(basename "$yaml_file" .yaml)

    # 检查文件是否包含域名相关规则并进行处理
    if grep -qE 'DOMAIN(-SUFFIX|-KEYWORD)?,|DOMAIN,' "$yaml_file"; then
        echo "Processing domain rules for $yaml_file..."
        
        # 创建一个新的JSON文件
        json_file="${base_name}_domain.json"
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\n      \"domain_suffix\": [],\n      \"domain_keyword\": [],\n      \"domain\": []\n    }\n  ]\n}" > "$json_file"
        
        while IFS= read -r line; do
            # 处理不同类型的域名规则
            if [[ "$line" =~ DOMAIN-SUFFIX,(.*) ]]; then
                domain="${BASH_REMATCH[1]}"
                # 使用sed命令将域名添加到对应的数组中
                sed -i "/\"domain_suffix\": \[/a\        \"$domain\"," "$json_file"
            elif [[ "$line" =~ DOMAIN-KEYWORD,(.*) ]]; then
                keyword="${BASH_REMATCH[1]}"
                # 使用sed命令将关键词添加到对应的数组中
                sed -i "/\"domain_keyword\": \[/a\        \"$keyword\"," "$json_file"
            elif [[ "$line" =~ DOMAIN,(.*) ]]; then
                domain_exact="${BASH_REMATCH[1]}"
                # 使用sed命令将准确的域名添加到对应的数组中
                sed -i "/\"domain\": \[/a\        \"$domain_exact\"," "$json_file"
            fi
        done < "$yaml_file"
        
        echo "Processed domain rules for $yaml_file."
        
    else
        echo "No domain rules found in $yaml_file. Skipping..."
    fi

    # 生成针对 Android 包名和进程名的 JSON
    if grep -q 'PROCESS-NAME,' "$yaml_file"; then
        grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp_process.json
        if [ -s temp_process.json ]; then
            echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
            sed 's/^/        "/;s/$/",/' temp_process.json >> "${base_name}_process.json"
            echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        fi
        rm -f temp_process.json
    fi

    # 生成针对 IP CIDR 的 JSON
    if grep -q 'IP-CIDR,' "$yaml_file"; then
        grep 'IP-CIDR,' "$yaml_file" | grep -v '#' | sed 's/  - IP-CIDR,//g' > temp_ipcidr.json
        if [ -s temp_ipcidr.json ]; then
            echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"ip_cidr\": [" > "${base_name}_ipcidr.json"
            sed 's/^/        "/;s/$/",/' temp_ipcidr.json >> "${base_name}_ipcidr.json"
            echo -e "      ]}\n  ]\n}" >> "${base_name}_ipcidr.json"
        fi
        rm -f temp_ipcidr.json
    fi
