#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${ROOT_DIR}/dist/MyCue.app}"
LAUNCH_MODE="${2:-finder}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

echo "==> Launching ${APP_PATH} via ${LAUNCH_MODE}"
pkill -x MyCue >/dev/null 2>&1 || true
sleep 1

case "${LAUNCH_MODE}" in
  finder)
    osascript -e "tell application \"Finder\" to open application file (POSIX file \"${APP_PATH}\")"
    ;;
  open)
    open "${APP_PATH}"
    ;;
  *)
    echo "Unsupported launch mode: ${LAUNCH_MODE}" >&2
    exit 1
    ;;
esac

sleep 3

echo "==> Running HID seize contention probe"
TMP_SWIFT="$(mktemp /tmp/mycue-touch-seize-XXXXXX.swift)"
cat > "${TMP_SWIFT}" <<'SWIFT'
import Foundation
import IOKit.hid

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let match: [String: Any] = [
    kIOHIDVendorIDKey as String: 10176,
    kIOHIDProductIDKey as String: 2137
]

IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
let managerOpen = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("managerOpen=\(managerOpen)")

let devices = ((IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []).sorted { lhs, rhs in
    let lhsUsagePage = (IOHIDDeviceGetProperty(lhs, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue ?? -1
    let rhsUsagePage = (IOHIDDeviceGetProperty(rhs, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue ?? -1
    if lhsUsagePage != rhsUsagePage {
        return lhsUsagePage < rhsUsagePage
    }
    let lhsUsage = (IOHIDDeviceGetProperty(lhs, kIOHIDPrimaryUsageKey as CFString) as? NSNumber)?.intValue ?? -1
    let rhsUsage = (IOHIDDeviceGetProperty(rhs, kIOHIDPrimaryUsageKey as CFString) as? NSNumber)?.intValue ?? -1
    return lhsUsage < rhsUsage
}

var successfulSeizes = 0
for device in devices {
    let usagePage = (IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue ?? -1
    let usage = (IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? NSNumber)?.intValue ?? -1
    let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
    print("device u\(usagePage):\(usage) seize=\(result)")
    if result == kIOReturnSuccess {
        successfulSeizes += 1
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}

IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))

if successfulSeizes == 0 {
    print("PASS: MyCue is holding the XENEON HID interfaces")
    exit(0)
} else {
    print("FAIL: \(successfulSeizes) XENEON HID interface(s) were still seizable by another process")
    exit(2)
}
SWIFT

set +e
swift "${TMP_SWIFT}"
RESULT=$?
set -e
rm -f "${TMP_SWIFT}"

exit "${RESULT}"
