# coding=utf-8
"""
大模型 API 调用模块
支持模型：gemini
"""

import json
import time
from google import genai
from google.genai import types

INDUSTRY_LIST = [
    "电池技术",
    "储能系统",
    "电池管理系统",
    "热管理",
    "电力电子",
    "储能安全",
    "AI/诊断",
    "再利用/回收"
]

IPC_LIST = [
    "H01M",
    "H01G",
    "H02J",
    "H02H",
    "G01R",
    "G05B",
    "F28D",
    "F24F",
    "H02M", 
    "H05B",
    "A62C",
    "G01N",
    "G06N",
    "G06F",
    "B09B",
    "C22B"
]

BASE_URL = "https://xinghuapi.com"

API_KEYS = {
    "gemini": "",
    "qwen": "",
    "kimi": ""
}

MODELS = {
    "gemini": "gemini-3-pro-preview",
    "qwen": "",
    "kimi": ""
}


def build_prompt(json_data):
    """
    构建分析 prompt（基于学术论文"Decoding China's Industrial Policy"方法论优化）

    Args:
        json_data: JSON 数据字典

    Returns:
        str: 构建好的 prompt
    """
    industry_list_str = "\n".join([f"- {ind}" for ind in INDUSTRY_LIST])
    ipc_list_str = "\n".join([f"- {ipc}" for ipc in IPC_LIST])

    prompt = f"""你是一个政策文本分析专家，专门分析中国电池储能系统的相关政策。

# 任务说明
请仔细阅读以下政策文件，分析其对电池储能系统的政策倾向性。

# 政策文件信息
标题：{json_data.get('title', '')}
制定机关：{json_data.get('制定机关', '')}
公布日期：{json_data.get('公布日期', '')}
施行日期：{json_data.get('施行日期', '')}
时效性：{json_data.get('时效性', '')}
效力位阶：{json_data.get('效力位阶', '')}
法规类别：{json_data.get('法规类别', '')}
全文（部分）：
{json_data.get('full_text', '')}

# 分析要求

## 1. 政策倾向性判断（核心任务，必须三选一）
【定义】判断该政策对电池储能产业的整体态度，并给出相应的倾向评分：
- **鼓励**：政策包含以下任一特征：
  * 提供直接激励：税收优惠、财政补贴、资金扶持、价格激励
  * 简化流程：放宽准入、简化审批、优先支持、试点示范
  * 提供便利：土地、人才、融资、并网服务支持
  * 设定积极目标：明确装机容量目标、产业发展规划
  * 鼓励外资、技术研发、项目建设
  * 关键词：鼓励、支持、推动、促进、保障、优先、扶持、奖励、补贴、示范、试点、简化、优化

- **中性**：政策包含以下任一特征：
  * 中性的规划、标准、规范、统计或信息类政策
  * 单纯提及电池储能，无明确激励或限制措施
  * 仅作一般性管理要求，无额外准入或监管加码
  * 技术标准、行业指南类文件，无明显倾向性
  * 关键词：规范、标准、指南、通知、管理、统计、监测

  - **限制**：政策包含以下任一特征：
  * 明确禁止、限制、约束类规定
  * 增设审批、备案、核准、安全准入等要求
  * 设定严格技术门槛、安全红线、退役标准
  * 列入负面清单、限制类或淘汰类产业目录
  * 强化监管、处罚、整改要求
  * 关键词：禁止、不得、严禁、限制、约束、严格、审批、核准、备案、准入

【重要】你必须且只能返回"鼓励"、"中性"或"限制"其中之一，请严格区分中性和鼓励性政策。


## 2. 其他分析项
- **是否BESS政策**：结合政策文本内容，判断该政策是否为电池储能系统（BESS）相关政策，只要对电池储能产业发展有影响的都可以算是，回答"是"或"否"
- **政策倾向评分**：结合政策文本，充分考虑政策的主体和客体、政策工具、发文主体和效力、政策目标和关键词频率，给出相应政策的倾向评分，范围为-1到1，鼓励性倾向为0.1到1，中性为-0.1到0.1，限制性倾向为-1到-0.1
- **政策倾向性判断依据**： 依据政策文本内容，1句话简要说明政策倾向性判断依据
- **地区**：依据制定机关判断，如果是省级机关，则填写省份名称；如果是地级市级机关，则填写地级市名称；如果是县、区或者县级市机关，则填写县、区或者县级市名称；如果是自治州、盟或者地区，则直接填写其名称；如果是中央机关则填"中央"
- **时效性**：根据"时效性"字段判断，只有"现行有效"才能填"生效","尚未施行"填"尚未生效",其他任何值都填"失效"
- **效力位阶类别**：结合效力位阶、制定机关和地区进行判断，务必严格区分地级市和县级市，其中，国务院、各部委等中央机关填"中央"，省级机关填"省级"、地级市机关填"地方-市级"、区/县/县级市机关填"地方-区/县级"、自治州/盟/地区级机关填"地方-自治州/盟/地区"
- **IPC范围**：从以下列表选择最相关的1-3个类别，如果没有相关的则填写"无匹配"：
{industry_list_str}，其中，电池技术包括电池、本征材料、结构等；储能系统包括电能存储、控制与保护、储能方式、系统集成等；电池管理系统包括BMS、监测、控制等；热管理包括散热、冷却、温控等；电力电子包括逆变器、变换器等；储能安全包括防火、防爆、消防、检测、化学分析等；AI/诊断包括智能运维、状态估计、故障诊断等；再利用/回收包括梯次利用、电池回收、拆解、材料回收等。
- **IPC分类**：从以下IPC列表选择最相关的1-6个类别，如果没有相关的则填写"无匹配"：
{ipc_list_str}，各IPC类别判定标准如下：
H01M：化学能直接转电能的方法或装置（如电池组），含一次/二次/燃料/混合电池及组合、未归类电化学发电器，同时涵盖各类电池通用零部件（电极、结构件等）及非燃料电池非活性部件制造方法。
H01G：电容器、电解型器件及光敏/热敏等器件；电介质材料选择、势垒电容器归入对应类别，遵附注优先级。索引含电容器（分固定/可变/混合/零部件）、电解器件、结构组合、制造四大类。
H02J：电力网络、供配电电路装置/系统及电能存储系统，含交直流配电、无线供电、智能电网操作等。索引涵盖各类供配电电路、电池组用装置、储能系统、无线供配电装置等。
H02H：电路反常时自动保护的紧急保护电路装置，含响应变化自动通断、特种设备保护、过流/过压限制、防误接通装置及相关零部件，仅针对反常工况防护。
G01R：电/磁变量、材料电/磁性质测量，设备测试，自旋效应装置及测试信号发生设备。明确"测量"含探测，遵G01附注，按仪器类型分类，索引涵盖电测仪器、各类变量测量、性能测试等。
G05B：通用控制/调节系统、功能单元及监视测试装置，"自动控制器"不含传感/校正单元，"电的"含机电等类型。索引含各类控制系统及比较单元、自动控制器等零部件。
F28D：其他类未含的非直接接触热交换设备及贮热装置。索引分无/有中间传热介质的热交换设备、贮热装置、其他热交换设备，细化通道组件等类型。
F24F：空调、增湿、通风及空气屏蔽应用，含人居空气处理。界定空调、通风定义，区分增湿类型，控制/安全装置对应分类，索引含空调装置、通风、能量回收等。
H02M：交直流转换、浪涌功率转换设备及配套控制装置，"变换"指电变量参数改变。索引含各类电转换方式、相关零部件，仅涵盖电功率变换电路及控制设备。
H05B：电热（含多种加热方式及零部件）、未归类电照明光源及通用电路，涵盖白炽灯、LED等各类光源操作电路，明确电热及光源核心范畴。
A62C：消防相关内容，索引含火灾预防/抑制、消焰器、各类灭火器、救火车辆、灭火物资输送、固定设备、控制装置及其他消防方法/设备/附件。
G01N：通过化学/物理性质测试分析材料，含固液气介质。索引涵盖取样制备、按性质/方法分类的测试分析、免疫测定、自动分析及其他未归类内容。
G06N：基于特定计算模型的计算机系统。
G06F：电数字数据处理，特定计算模型系统归入G06N。"处理"含数据处理/传送，索引涵盖数据处理、输入输出、模式识别、安全装置、辅助设计等。
B09B：其他类未含的固体废物处理及污染土壤再生，仅含无法单一归类的作业。"处理"指废物清除、破坏或无害化，固体废物含含液但按固体对待的类型。
C22B：金属生产/精炼及原材料预处理，含非冶金提金属、冶金制金属化合物，砷锑单质及冶金化合物归入此类，其化合物分至对应类目。索引含预处理、提取、精炼等。
- **IPC范围及分类总结**：一句话概括判断该政策涉及的IPC范围以及分类的理由，如果没有匹配的IPC范围或者类别则说明原因，是政策过于宽泛还是不在所提供的IPC目录中
- **可信度**：对以上分析结果特别是倾向性判断、IPC分类判断以及是否BESS政策的可信度进行自我评估，分值为0-1，保留两位小数，1表示非常有把握，0表示完全没有把握

# 输出格式
请严格按照以下JSON格式返回（不要包含任何其他文字）：
{{
    "地区": "xx省/xx市/中央",
    "时效性": "生效/尚未生效/失效",
    "效力位阶类别": "中央/地方",
    "是否BESS政策": "是/否",
    "IPC范围": "范围1,范围2",
    "IPC分类": "IPC1,IPC2,IPC3",
    "IPC范围及分类总结": "一句话说明判定依据",
    "政策倾向性": "鼓励/中性/限制",
    "政策倾向性评分"："介于-1.00到1.00之间的数值，保留两位小数",
    "政策倾向性判断依据": "一句话说明判定依据",
    "可信度": "0.00-1.00之间的数值，保留两位小数"
}}
"""
    return prompt


def call_llm_api(prompt, model_name, max_retries=3):
    """
    调用大模型 API

    Args:
        prompt: 提示词
        model_name: 模型名称(gemini)
        max_retries: 最大重试次数

    Returns:
        dict: 解析后的结果字典，如果失败返回 None
    """
    model_id = MODELS.get(model_name)
    if not model_id:
        print(f"错误：未知的模型名称 {model_name}")
        return None

    api_key = API_KEYS.get(model_name)
    if not api_key:
        print(f"错误：模型 {model_name} 没有配置 API key")
        return None

    for attempt in range(max_retries):
        try:
            print(f"正在调用模型 {model_name}（尝试 {attempt + 1}/{max_retries}）...")
            
            client = genai.Client(
                api_key=api_key,
                http_options={"base_url": BASE_URL}
            )
            
            response = client.models.generate_content(
                model=model_id,
                contents=types.Content(
                    parts=[
                        types.Part(text=prompt)
                    ]
                )
            )
            
            content = response.text

            try:
                if "```json" in content:
                    start = content.find("```json") + 7
                    end = content.find("```", start)
                    json_str = content[start:end].strip()
                elif "```" in content:
                    start = content.find("```") + 3
                    end = content.find("```", start)
                    json_str = content[start:end].strip()
                else:
                    start = content.find("{")
                    end = content.rfind("}") + 1
                    if start != -1 and end > start:
                        json_str = content[start:end]
                    else:
                        json_str = content

                result = json.loads(json_str)
                return result

            except json.JSONDecodeError as e:
                print(f"警告：无法解析模型 {model_name} 返回的 JSON: {e}")
                print(f"原始内容: {content[:200]}")
                return None

        except Exception as e:
            print(f"API 请求失败（尝试 {attempt + 1}/{max_retries}）：{e}")
            if attempt < max_retries - 1:
                time.sleep(2)  
            else:
                return None

    return None


def analyze_policy(json_data, model_name):
    """
    分析政策文件

    Args:
        json_data: JSON 数据字典
        model_name: 模型名称（gemini）

    Returns:
        dict: 分析结果
    """
    prompt = build_prompt(json_data)
    result = call_llm_api(prompt, model_name)

    if result:
        default_result = {
            "地区": "未知",
            "时效性": "未知",
            "效力位阶类别": "未知",
            "是否BESS政策": "未知",
            "IPC范围": "未知",
            "IPC分类": "未知",
            "IPC范围及分类总结": "未知",
            "政策倾向性": "未知",
            "政策倾向性评分": "未知",
            "政策倾向性判断依据": "未知",  
            "可信度": "未知"
        }
        default_result.update(result)
        return default_result
    else:
        return {
            "地区": "API调用失败",
            "时效性": "API调用失败",
            "效力位阶类别": "API调用失败",
            "是否BESS政策": "API调用失败",
            "IPC范围": "API调用失败",
            "IPC分类": "API调用失败",
            "IPC范围及分类总结": "API调用失败",
            "政策倾向性": "API调用失败",
            "政策倾向性评分": "API调用失败",
            "政策倾向性判断依据": "API调用失败",
            "可信度": "API调用失败"
        }


if __name__ == '__main__':
    test_data = {
        "url": "https://www.pkulaw.com/test",
        "title": "测试政策",
        "制定机关": "国务院",
        "公布日期": "2023.01.01",
        "施行日期": "2023.01.01",
        "时效性": "现行有效",
        "效力位阶": "行政法规",
        "full_text": "这是一个测试政策文本..."
    }

    print("测试 API 调用...")
    result = analyze_policy(test_data, "gemini")  
    print("\n结果：")
    print(json.dumps(result, ensure_ascii=False, indent=2))