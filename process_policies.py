# coding=utf-8
"""
政策文件处理主脚本
遍历 JSON 文件，调用大模型分析，生成 CSV
"""

import os
import json
import csv
import time
from pathlib import Path
from llm_api_gemini import analyze_policy, MODELS

def process_json_file(json_path, file_index, model_name):
    """
    处理单个 JSON 文件

    Args:
        json_path: JSON 文件路径
        file_index: 文件序号（用作编码）
        model_name: 模型名称

    Returns:
        dict: CSV 行数据，如果失败返回 None
    """
    try:
        print(f"\n[{model_name}] 正在处理文件 #{file_index}: {os.path.basename(json_path)}")

        with open(json_path, 'r', encoding='utf-8') as f:
            json_data = json.load(f)

        print(f"[{model_name}] 已读取 JSON，准备调用大模型...")

        url = json_data.get('url', '')
        title = json_data.get('title', '')
        publish_date = json_data.get('公布日期', '')
        effective_date = json_data.get('施行日期', '')
        effectiveness_original = json_data.get('效力位阶', '')
        law_category = json_data.get('法规类别', '')  
        analysis = analyze_policy(json_data, model_name)
        print(f"[{model_name}] 大模型分析完成")

        row = {
            '编码': f"P{file_index:06d}",
            'url': url,
            'title': title,
            '地区': analysis.get('地区', '未知'),
            '公布日期': publish_date,
            '施行日期': effective_date,
            '时效性': analysis.get('时效性', '未知'),
            '效力位阶_原始': effectiveness_original,
            '效力位阶_分类': analysis.get('效力位阶类别', '未知'),
            '法规类别': law_category,  # 新增：法规类别
            '是否BESS政策': analysis.get('是否BESS政策', '未知'),
            'IPC_范围': analysis.get('IPC范围', '未知'),
            'IPC_分类': analysis.get('IPC分类', '未知'),
            'IPC_范围及分类总结': analysis.get('IPC范围及分类总结', '未知'),
            '政策倾向性': analysis.get('政策倾向性', '未知'),
            '政策倾向性评分': analysis.get('政策倾向性评分', '未知'),
            '政策倾向性判断依据': analysis.get('政策倾向性判断依据', '未知'),
            '可信度': analysis.get('可信度', '未知')
        }

        return row

    except Exception as e:
        print(f"错误：处理文件 {json_path} 时出错: {e}")
        return None


def process_all_files(source_dir, output_csv_prefix, model_name, start_index=0, max_files=None):
    """
    处理所有 JSON 文件

    Args:
        source_dir: 源文件夹路径
        output_csv_prefix: 输出 CSV 文件前缀
        model_name: 模型名称
        start_index: 起始索引（用于断点续传）
        max_files: 最大处理文件数（用于测试）
    """
    output_csv = f"{output_csv_prefix}_{model_name}.csv"

    fieldnames = [
        '编码', 'url', 'title', '地区', '公布日期', '施行日期',
        '时效性', '效力位阶_原始', '效力位阶_分类', '法规类别', '是否BESS政策',
        'IPC_范围', 'IPC_分类', 'IPC_范围及分类总结', '政策倾向性', '政策倾向性评分','政策倾向性判断依据','可信度'
    ]

    json_files = []
    for root, dirs, files in os.walk(source_dir):
        for filename in files:
            if filename.endswith('.json'):
                json_files.append(os.path.join(root, filename))

    total_files = len(json_files)
    print(f"\n{'='*60}")
    print(f"模型：{model_name} ({MODELS[model_name]})")
    print(f"总文件数：{total_files}")
    print(f"输出文件：{output_csv}")
    print(f"{'='*60}\n")

    if max_files:
        json_files = json_files[:max_files]
        print(f"测试模式：仅处理前 {max_files} 个文件\n")

    file_exists = os.path.exists(output_csv)
    write_mode = 'a' if file_exists and start_index > 0 else 'w'

    with open(output_csv, write_mode, newline='', encoding='utf-8-sig') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        if write_mode == 'w':
            writer.writeheader()

        success_count = 0
        error_count = 0
        start_time = time.time()

        for i, json_path in enumerate(json_files[start_index:], start=start_index):
            row = process_json_file(json_path, i + 1, model_name)

            if row:
                writer.writerow(row)
                success_count += 1

                if success_count % 10 == 0:
                    csvfile.flush()

                if success_count % 50 == 0:
                    elapsed = time.time() - start_time
                    rate = success_count / elapsed if elapsed > 0 else 0
                    print(f"[{model_name}] 进度：{success_count}/{len(json_files)} "
                          f"({success_count*100/len(json_files):.1f}%) "
                          f"- 速度：{rate:.2f} 文件/秒")
            else:
                error_count += 1

            time.sleep(0.5)

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"[{model_name}] 处理完成！")
    print(f"{'='*60}")
    print(f"成功处理：{success_count} 个文件")
    print(f"失败：{error_count} 个文件")
    print(f"总耗时：{elapsed/60:.2f} 分钟")
    print(f"平均速度：{success_count/elapsed:.2f} 文件/秒")
    print(f"输出文件：{output_csv}")
    print(f"{'='*60}\n")


def main():
    """主函数"""
    source_dir = 'bess_jsons_unique'
    output_csv_prefix = 'policy_analysis'

    print("="*60)
    print("政策文件分析系统")
    print("="*60)
    print("\n请选择运行模式：")
    print("1. 测试模式（仅处理前10个文件）")
    print("2. 完整模式（处理所有文件）")

    choice = input("\n请输入选项（1或2）：").strip()

    if choice == '1':
        max_files = 10
        print("\n已选择测试模式")
    else:
        max_files = None
        print("\n已选择完整模式")

    print("\n请选择要使用的模型（可多选，用逗号分隔）：")
    print("1. gemini (gemini-2.5-pro)")
    print("2. qwen (qwen3-235b-a22b-thinking-2507)")
    print("3. kimi (kimi-k2-instruct)")
    print("4. all (所有模型)")

    model_choice = input("\n请输入选项（如：1,2 或 all）：").strip()

    if model_choice == 'all' or model_choice == '4':
        selected_models = ['gemini', 'qwen', 'kimi']
    else:
        model_map = {'1': 'gemini', '2': 'qwen', '3': 'kimi'}
        selected_models = [model_map[c.strip()] for c in model_choice.split(',') if c.strip() in model_map]

    if not selected_models:
        print("错误：未选择有效的模型")
        return

    print(f"\n将使用以下模型：{', '.join(selected_models)}")
    print("\n开始处理...\n")

    for model_name in selected_models:
        try:
            process_all_files(source_dir, output_csv_prefix, model_name, max_files=max_files)
        except Exception as e:
            print(f"错误：处理模型 {model_name} 时出错: {e}")
            continue

    print("\n所有任务完成！")


if __name__ == '__main__':
    main()
