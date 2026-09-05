import Foundation
import TokeniCore
import TokeniWindowsNative

public enum WindowsCompanionInventory {
    public static func takeAction() -> WindowsCompanionAction? {
        var id = [CChar](repeating: 0, count: 128), text = [CChar](repeating: 0, count: 256)
        let code = tokeni_windows_take_action(&id, 128, &text, 256)
        let identifier = id.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        let name = text.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        switch code {
        case 552: return UUID(uuidString: identifier).map { .rename($0, name) }
        case 553: return UUID(uuidString: identifier).map { .showcase($0) }
        case 557: return .checkIn
        case 570: return UUID(uuidString: identifier).map { .openEgg($0) }
        case 571: return UUID(uuidString: identifier).map { .sellEgg($0) }
        case 572:
            if identifier.hasPrefix("egg:") { return .buyEgg(CompanionEggDefinitionID(rawValue: String(identifier.dropFirst(4)))) }
            return CompanionCosmeticID(rawValue: identifier).map { .buyCosmetic($0) }
        case 573: return CompanionCosmeticID(rawValue: identifier).map { .equipCosmetic($0) }
        default: return nil
        }
    }

    public static func publish(state: CompanionGameState?, rewards: CompanionRewardState?) {
        tokeni_windows_inventory_begin()
        func append(_ group: Int32, _ id: String, _ label: String) {
            id.withCString { id in String(label.prefix(120)).withCString { label in tokeni_windows_inventory_append(group, id, label) } }
        }
        if let state {
            for egg in state.eggs {
                append(1, egg.id.uuidString, "\(egg.definitionID.rawValue) · \(egg.id.uuidString.prefix(8))")
            }
            for definition in CompanionEggRegistry.definitions {
                guard let price = definition.price else { continue }
                let unlocked = CompanionEggRegistry.isUnlocked(definition, highestPetLevel: state.highestPetLevel,
                    discoveredSpeciesCount: state.collection.discoveredSpeciesIDs.count)
                append(2, "egg:\(definition.id.rawValue)", WindowsLocalization.text("Egg", "알") + " · \(definition.id.rawValue) · ★ \(price)"
                    + (unlocked ? "" : WindowsLocalization.text(" · Locked", " · 잠김")))
            }
        }
        for cosmetic in CompanionRewardEngine().cosmetics {
            let owned = rewards?.unlockedCosmeticIDs.contains(cosmetic.id) == true
            let equipped = rewards?.selectedCosmeticIDs.contains(cosmetic.id) == true
            append(2, cosmetic.id.rawValue, "\(cosmetic.id.rawValue) · ★ \(cosmetic.cost)"
                + (equipped ? WindowsLocalization.text(" · Equipped", " · 장착 중") : owned ? WindowsLocalization.text(" · Owned", " · 보유") : ""))
        }
        let summary = rewards.map { WindowsLocalization.text("Star shards: \($0.starShards)\nCheck in daily to receive rewards. Select a cosmetic to buy or equip it; select it again to unequip.",
            "별 조각: \($0.starShards)\n매일 출석 보상을 받을 수 있습니다. 꾸미기를 구매하거나 장착하세요. 장착한 항목을 다시 선택하면 해제됩니다.") }
            ?? WindowsLocalization.text("Rewards unavailable. Restart to retry.", "보상을 불러오지 못했습니다. 앱을 다시 실행해 주세요.")
        summary.replacingOccurrences(of: "\n", with: "\r\n").withCString { tokeni_windows_inventory_commit($0) }
        var mask: UInt32 = 0
        for (index, id) in CompanionCosmeticID.allCases.enumerated() where rewards?.selectedCosmeticIDs.contains(id) == true {
            mask |= 1 << index
        }
        tokeni_windows_overlay_set_cosmetics(mask)
    }

    public static func errorMessage(_ error: any Error) -> String {
        if error as? CompanionRewardError == .insufficientStarShards { return WindowsLocalization.text("Not enough star shards.", "별 조각이 부족합니다.") }
        if error as? CompanionEggError == .eggLocked { return WindowsLocalization.text("This egg is locked. Reach its level or collection requirement first.", "아직 잠긴 알입니다. 레벨 또는 수집 조건을 먼저 충족해 주세요.") }
        return WindowsLocalization.text("The action could not be completed. Check ownership, balance and eligibility. Restart if saving failed.", "작업을 완료하지 못했습니다. 보유 상태·잔액·조건을 확인하세요. 저장에 실패했다면 앱을 다시 실행해 주세요.")
    }
}
