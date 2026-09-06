// Bilingual display names from the shared product localization catalogs.
import TokeniCore

public enum WindowsCompanionNames {
    public static func text(_ key: String, fallback: String) -> String {
        guard let pair = labels[key] else { return fallback }
        return WindowsLocalization.text(pair.0, pair.1)
    }
    public static func species(_ id: CompanionSpeciesID) -> String {
        text("companion.species.\(id.rawValue).name", fallback: id.rawValue)
    }
    public static func egg(_ id: CompanionEggDefinitionID) -> String {
        text("companion.egg.\(id.rawValue)", fallback: id.rawValue)
    }
    public static func cosmetic(_ id: CompanionCosmeticID) -> String {
        text("companion.cosmetic.\(id.rawValue)", fallback: id.rawValue)
    }
    private static let labels: [String: (String, String)] = [
        "companion.cosmetic.azurePalette": ("Legacy Azure Color", "레거시 블루 컬러"),
        "companion.cosmetic.buy": ("Buy", "구매"),
        "companion.cosmetic.cloudCushion": ("Cloud Cushion", "구름 방석"),
        "companion.cosmetic.cloudGarden": ("Cloud Garden", "구름 정원"),
        "companion.cosmetic.constellationFrame": ("Constellation Frame", "별자리 프레임"),
        "companion.cosmetic.description": ("Purchased cosmetics are permanent and never affect growth or rarity.", "구매한 꾸미기는 영구 보관되며 펫의 성장이나 등급에는 영향을 주지 않습니다."),
        "companion.cosmetic.driftingClouds": ("Drifting Clouds", "떠다니는 구름"),
        "companion.cosmetic.earning": ("Earn Star Shards through verified growth, pet discoveries, and collection milestones.", "별조각은 검증된 성장과 펫 발견·도감 달성으로 얻습니다."),
        "companion.cosmetic.equip": ("Equip", "착용"),
        "companion.cosmetic.equipped": ("Equipped", "착용 중"),
        "companion.cosmetic.fallingPetals": ("Falling Petals", "흩날리는 꽃잎"),
        "companion.cosmetic.fireflyAura": ("Firefly Aura", "반딧불 오라"),
        "companion.cosmetic.hologramPlatform": ("Hologram Platform", "홀로그램 발판"),
        "companion.cosmetic.hologramScanlines": ("Hologram Scanlines", "홀로그램 스캔라인"),
        "companion.cosmetic.insufficient": ("Need more shards", "별조각 부족"),
        "companion.cosmetic.meadowPatch": ("Flower Meadow Mat", "꽃밭 매트"),
        "companion.cosmetic.miniDrone": ("Tiny Drone", "꼬마 드론"),
        "companion.cosmetic.missing": ("Need %d more", "%d개 더 필요"),
        "companion.cosmetic.orbitAura": ("Orbit Aura", "궤도 오라"),
        "companion.cosmetic.owned": ("Owned", "보유 중"),
        "companion.cosmetic.pixelChick": ("Pixel Chick", "픽셀 병아리"),
        "companion.cosmetic.pixelForest": ("Pixel Forest", "픽셀 숲"),
        "companion.cosmetic.pixelHearts": ("Pixel Hearts", "픽셀 하트"),
        "companion.cosmetic.pixelPortalFrame": ("Pixel Portal Frame", "픽셀 포털 프레임"),
        "companion.cosmetic.preview": ("Preview", "미리보기"),
        "companion.cosmetic.price": ("%d Star Shards", "별조각 %d개"),
        "companion.cosmetic.remove": ("Remove", "해제"),
        "companion.cosmetic.shop": ("Star Shard cosmetics", "별조각 꾸미기"),
        "companion.cosmetic.sparkleAura": ("Sparkle Aura", "반짝임 오라"),
        "companion.cosmetic.starSprite": ("Starlight Sprite", "별빛 요정"),
        "companion.cosmetic.sunsetGrid": ("Sunset Grid", "노을 그리드"),
        "companion.cosmetic.terminalNight": ("Terminal Night", "터미널 나이트"),
        "companion.cosmetic.violetPalette": ("Legacy Violet Color", "레거시 바이올렛 컬러"),
        "companion.egg.discovery": ("Starlight Egg", "별빛 알"),
        "companion.egg.homecoming": ("Homecoming Egg", "귀환 선물 알"),
        "companion.egg.mystery": ("Mystery Egg", "수수께끼 알"),
        "companion.egg.prismatic": ("Prismatic Egg", "프리즘 알"),
        "companion.egg.starter": ("Starter Egg", "스타터 알"),
        "companion.species.bytebot.name": ("ByteBot", "ByteBot"),
        "companion.species.cachecat.name": ("CacheCat", "CacheCat"),
        "companion.species.kernelcrab.name": ("KernelCrab", "KernelCrab"),
        "companion.species.loophare.name": ("LoopHare", "LoopHare"),
        "companion.species.mystery.name": ("Mystery Egg", "수수께끼 알"),
        "companion.species.nullslime.name": ("NullSlime", "NullSlime"),
        "companion.species.patchpanda.name": ("PatchPanda", "PatchPanda"),
        "companion.species.promptpup.name": ("PromptPup", "PromptPup"),
        "companion.species.queryowl.name": ("QueryOwl", "QueryOwl"),
        "companion.species.relayray.name": ("RelayRay", "RelayRay"),
        "companion.species.stackfox.name": ("StackFox", "StackFox"),
    ]
}

