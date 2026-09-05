import Foundation
import TokeniWindowsNative

public enum WindowsLocalization {
    public static var isKorean: Bool { tokeni_windows_dashboard_is_korean() != 0 }
    public static func text(_ english: String, _ korean: String) -> String {
        self.isKorean ? korean : english
    }
    public static func message(_ english: String) -> String {
        guard self.isKorean else { return english }
        return [
            "Waiting for data": "데이터 대기 중", "Connected": "연결됨", "Refreshing": "갱신 중",
            "Stale · refresh needed": "오래된 데이터 · 갱신 필요", "Unavailable": "사용 불가", "Refresh failed": "갱신 실패",
            "Waiting for first refresh": "첫 갱신 대기 중", "Refreshing provider usage…": "사용량 갱신 중…",
            "Start with Windows enabled.": "Windows 자동 시작을 켰습니다.",
            "Start with Windows disabled.": "Windows 자동 시작을 껐습니다.",
            "Start with Windows could not be changed.": "자동 시작 설정을 변경하지 못했습니다.",
            "Test notification sent.": "테스트 알림을 보냈습니다.", "Test notification could not be sent.": "테스트 알림을 보내지 못했습니다.",
            "Companion overlay enabled.": "데스크톱 펫을 표시합니다.", "Companion overlay disabled.": "데스크톱 펫을 숨겼습니다.",
            "Companion overlay could not be changed.": "데스크톱 펫 표시를 변경하지 못했습니다.",
            "Growth target saved.": "성장 대상을 저장했습니다.", "Growth target could not be saved.": "성장 대상을 저장하지 못했습니다.",
            "Your new companion is ready.": "새로운 펫이 태어났습니다.",
            "The egg could not be opened. Your saved state is unchanged.": "알을 열지 못했습니다. 기존 저장 상태는 유지됩니다.",
            "Companion state could not be loaded. Restart Tokeni Bar to retry.": "펫 상태를 불러오지 못했습니다. 앱을 다시 실행해 주세요.",
            "No provider usage is available yet.": "아직 사용량 데이터가 없습니다.",
            "All providers are disabled. Enable a provider above to start tracking usage.": "설정에서 제공자를 켜면 사용량을 확인할 수 있습니다.",
            "No history in this period": "이 기간에는 기록이 없습니다",
            "All providers are disabled. Select a provider above to view usage.": "설정에서 제공자를 켜면 사용량을 확인할 수 있습니다.",
            "Provider selection is unavailable in this Windows build.": "이 Windows 버전에서는 제공자를 선택할 수 없습니다.",
        ][english] ?? english
    }
}
