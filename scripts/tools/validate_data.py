#!/usr/bin/env python3
"""
WOTW 数据校验工具
用法：
  python validate_data.py          # 校验所有数据文件
  python validate_data.py --watch  # 监视模式，文件变更时自动重新校验
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

DATA_ROOT = Path(__file__).parent.parent.parent / "assets" / "data"

# ---- 校验规则 ----

def validate_skills(data_dir: Path) -> list[str]:
    """校验武学数据"""
    errors = []

    # 校验外功
    ext_path = data_dir / "skills" / "external_skills.json"
    if ext_path.exists():
        with open(ext_path, "r", encoding="utf-8") as f:
            ext = json.load(f)
        for skill in ext.get("externalSkills", []):
            if not skill.get("id"):
                errors.append(f"外功缺少id: {skill.get('name', 'unknown')}")
            if not skill.get("techniques"):
                errors.append(f"外功 {skill['id']} 没有招式")
            for tech in skill.get("techniques", []):
                if tech.get("qiCost", 0) < 0:
                    errors.append(f"{skill['id']}.{tech['id']} 内力消耗不能为负")
                if tech.get("cooldown", 0) < 0:
                    errors.append(f"{skill['id']}.{tech['id']} 冷却不能为负")
            # 检查连击链引用的招式ID是否存在
            tech_ids = {t["id"] for t in skill.get("techniques", [])}
            for chain in skill.get("comboChains", []):
                for tid in chain.get("sequence", []):
                    if tid not in tech_ids:
                        errors.append(f"{skill['id']} 连击链引用了不存在的招式: {tid}")

    # 校验内功
    int_path = data_dir / "skills" / "internal_skills.json"
    if int_path.exists():
        with open(int_path, "r", encoding="utf-8") as f:
            internal = json.load(f)
        for skill in internal.get("internalSkills", []):
            realms = skill.get("realms", [])
            if len(realms) != 7:
                errors.append(f"内功 {skill['id']} 境界数不为7（实际{len(realms)}）")
            for i, realm in enumerate(realms):
                if realm.get("level") != i + 1:
                    errors.append(f"内功 {skill['id']} 境界{i+1}的level字段不匹配")

    # 校验轻功
    lgt_path = data_dir / "skills" / "lightness_skills.json"
    if lgt_path.exists():
        with open(lgt_path, "r", encoding="utf-8") as f:
            lightness = json.load(f)
        for skill in lightness.get("lightnessSkills", []):
            if skill.get("combatMovementBonus", 0) < 0:
                errors.append(f"轻功 {skill['id']} 移动加成不能为负")

    return errors


def validate_items(data_dir: Path) -> list[str]:
    """校验物品数据"""
    errors = []
    items_path = data_dir / "items" / "items.json"
    if not items_path.exists():
        return ["items.json 不存在"]

    with open(items_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    item_ids = set()

    for equip in data.get("equipment", []):
        if equip["id"] in item_ids:
            errors.append(f"装备ID重复: {equip['id']}")
        item_ids.add(equip["id"])
        if equip.get("levelRequired", 1) < 1:
            errors.append(f"装备 {equip['id']} 等级要求无效")

    for cons in data.get("consumables", []):
        if cons["id"] in item_ids:
            errors.append(f"消耗品ID重复: {cons['id']}")
        item_ids.add(cons["id"])

    for mat in data.get("materials", []):
        if mat["id"] in item_ids:
            errors.append(f"材料ID重复: {mat['id']}")
        item_ids.add(mat["id"])
        valid_regions = {"zhongyuan", "shuzhong", "beining", "donghai", "nanjiang", "xiyu"}
        for region in mat.get("sourceRegions", []):
            if region not in valid_regions:
                errors.append(f"材料 {mat['id']} 引用了不存在的区域: {region}")

    # 校验制造配方的材料引用
    for equip in data.get("equipment", []):
        recipe = equip.get("craftRecipe")
        if recipe:
            for mat_id in recipe.get("materials", {}):
                if mat_id not in item_ids:
                    errors.append(f"装备 {equip['id']} 配方引用了不存在的材料: {mat_id}")

    for cons in data.get("consumables", []):
        recipe = cons.get("craftRecipe")
        if recipe:
            for mat_id in recipe.get("materials", {}):
                if mat_id not in item_ids:
                    errors.append(f"消耗品 {cons['id']} 配方引用了不存在的材料: {mat_id}")

    return errors


def validate_characters(data_dir: Path) -> list[str]:
    """校验角色数据"""
    errors = []
    char_dir = data_dir / "characters"

    # 校验出身
    origins_path = char_dir / "origins.json"
    if origins_path.exists():
        with open(origins_path, "r", encoding="utf-8") as f:
            origins = json.load(f)
        for origin in origins.get("origins", []):
            attrs = origin.get("bonusAttributes", {})
            total = sum(attrs.values())
            if total != 8:
                errors.append(f"出身 {origin['id']} 属性加成总和应为8（实际{total}）")

    # 校验同伴
    comp_path = char_dir / "companions.json"
    if comp_path.exists():
        with open(comp_path, "r", encoding="utf-8") as f:
            comps = json.load(f)
        for comp in comps.get("companions", []):
            if not comp.get("exclusiveSkill"):
                errors.append(f"同伴 {comp['id']} 没有专属武学")

    return errors


def validate_quests(data_dir: Path) -> list[str]:
    """校验任务数据"""
    errors = []
    quests_path = data_dir / "quests" / "quests.json"
    if not quests_path.exists():
        return ["quests.json 不存在"]

    with open(quests_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    all_quest_ids = set()

    for quest_list_key in ["mainQuests", "sideQuests", "dailyQuests"]:
        for quest in data.get(quest_list_key, []):
            if quest["id"] in all_quest_ids:
                errors.append(f"任务ID重复: {quest['id']}")
            all_quest_ids.add(quest["id"])
            if not quest.get("objectives"):
                errors.append(f"任务 {quest['id']} 没有目标")

    # 校验任务前置依赖
    for quest_list_key in ["mainQuests", "sideQuests", "dailyQuests"]:
        for quest in data.get(quest_list_key, []):
            prereqs = quest.get("prerequisites", {}).get("quests", [])
            for prereq_id in prereqs:
                if prereq_id not in all_quest_ids:
                    errors.append(f"任务 {quest['id']} 的前置任务 {prereq_id} 不存在")

    # 校验对话树节点引用
    for dlg in data.get("dialogues", []):
        node_ids = set(dlg.get("nodes", {}).keys())
        if dlg["startNode"] not in node_ids:
            errors.append(f"对话树 {dlg['id']} 的起始节点 {dlg['startNode']} 不存在")
        for node_id, node in dlg.get("nodes", {}).items():
            for choice in node.get("choices", []):
                next_node = choice.get("nextNode")
                if next_node and next_node != "node_end" and next_node not in node_ids:
                    errors.append(f"对话树 {dlg['id']} 节点 {node_id} 引用了不存在的节点: {next_node}")
            next_node = node.get("nextNode")
            if next_node and next_node != "node_end" and next_node not in node_ids:
                errors.append(f"对话树 {dlg['id']} 节点 {node_id} 的nextNode不存在: {next_node}")

    return errors


def validate_world(data_dir: Path) -> list[str]:
    """校验世界数据"""
    errors = []
    world_path = data_dir / "world" / "world.json"
    if not world_path.exists():
        return ["world.json 不存在"]

    with open(world_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    scene_ids = set()
    for region in data.get("regions", []):
        for scene in region.get("scenes", []):
            if scene["id"] in scene_ids:
                errors.append(f"场景ID重复: {scene['id']}")
            scene_ids.add(scene["id"])

    # 校验场景连接
    for region in data.get("regions", []):
        for scene in region.get("scenes", []):
            for conn_id in scene.get("connectedScenes", []):
                if conn_id not in scene_ids:
                    errors.append(f"场景 {scene['id']} 连接了不存在的场景: {conn_id}")

    # 校验天气池权重
    for region in data.get("regions", []):
        weather_pool = region.get("weatherPool", [])
        if weather_pool:
            total_weight = sum(w["weight"] for w in weather_pool)
            if abs(total_weight - 1.0) > 0.01:
                errors.append(f"区域 {region['id']} 天气权重之和不为1（实际{total_weight:.2f}）")

    return errors


# ---- 主程序 ----

def validate_all(data_root: Path) -> dict[str, list[str]]:
    results = {
        "武学数据": validate_skills(data_root),
        "物品数据": validate_items(data_root),
        "角色数据": validate_characters(data_root),
        "任务数据": validate_quests(data_root),
        "世界数据": validate_world(data_root),
    }
    return results


def print_results(results: dict[str, list[str]]):
    total_errors = sum(len(v) for v in results.values())
    timestamp = datetime.now().strftime("%H:%M:%S")

    print(f"\n{'='*50}")
    print(f"  WOTW 数据校验报告 [{timestamp}]")
    print(f"{'='*50}")

    for category, errors in results.items():
        status = "✓ 通过" if not errors else f"✗ {len(errors)} 个错误"
        print(f"  {category}: {status}")
        for err in errors:
            print(f"    → {err}")

    print(f"{'='*50}")
    if total_errors == 0:
        print(f"  结果: 全部通过 ✓")
    else:
        print(f"  结果: 共 {total_errors} 个错误 ✗")
    print(f"{'='*50}\n")
    return total_errors


def main():
    watch_mode = "--watch" in sys.argv

    if watch_mode:
        print("监视模式启动，文件变更时自动校验... (Ctrl+C 退出)")
        import time
        last_mtimes = {}
        while True:
            current_mtimes = {}
            for root, dirs, files in os.walk(DATA_ROOT):
                for f in files:
                    if f.endswith(".json"):
                        fp = os.path.join(root, f)
                        current_mtimes[fp] = os.path.getmtime(fp)

            if current_mtimes != last_mtimes:
                results = validate_all(DATA_ROOT)
                print_results(results)
                last_mtimes = current_mtimes

            time.sleep(2)
    else:
        results = validate_all(DATA_ROOT)
        exit_code = print_results(results)
        sys.exit(0 if exit_code == 0 else 1)


if __name__ == "__main__":
    main()