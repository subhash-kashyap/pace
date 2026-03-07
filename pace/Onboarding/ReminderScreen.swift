import SwiftUI
import UserNotifications

struct ReminderScreen: View {
    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Want a daily nudge to focus?")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            Text("Pace will remind you once a day to open your focus session")
                .font(.system(size: 18))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 150)
            
            VStack(spacing: 15) {
                Button(action: {
                    print("🔔 ReminderScreen: 'Yes, remind me' clicked")
                    checkAndScheduleNotification()
                }) {
                    Text("Yes, remind me")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    print("⏭️ ReminderScreen: 'No thanks' clicked")
                    onComplete()
                }) {
                    Text("No thanks")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.5))
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            print("👁️ ReminderScreen appeared")
            // Set default to 9:00 AM
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            if let defaultDate = Calendar.current.date(from: components) {
                reminderTime = defaultDate
            }
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("Notifications Disabled"),
                message: Text("Pace needs permission to send reminders. Please enable them in System Settings > Notifications."),
                primaryButton: .default(Text("Open Settings")) {
                    print("⚙️ ReminderScreen: Opening Notification Settings")
                    openNotificationSettings()
                },
                secondaryButton: .cancel(Text("Not Now")) {
                    print("🛑 ReminderScreen: Permission alert dismissed")
                    onComplete()
                }
            )
        }
    }
    
    private func checkAndScheduleNotification() {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            print("📊 ReminderScreen: Current settings status: \(settings.authorizationStatus.rawValue)")
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    requestPermissionAndSchedule()
                case .denied:
                    showingPermissionAlert = true
                case .authorized, .provisional, .ephemeral:
                    scheduleActualNotification()
                @unknown default:
                    onComplete()
                }
            }
        }
    }
    
    private func requestPermissionAndSchedule() {
        print("🔐 ReminderScreen: Requesting authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("🔐 ReminderScreen: Authorization granted: \(granted)")
            if let error = error { print("❌ ReminderScreen: Auth error: \(error)") }
            
            DispatchQueue.main.async {
                if granted {
                    scheduleActualNotification()
                } else {
                    onComplete()
                }
            }
        }
    }
    
    private func scheduleActualNotification() {
        print("📅 ReminderScreen: Scheduling notification for \(reminderTime)")
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Time to focus 🎯"
        content.body = "Open Pace and get into it."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error { print("❌ ReminderScreen: Schedule error: \(error)") }
            else { print("✅ ReminderScreen: Notification scheduled") }
            
            DispatchQueue.main.async {
                onComplete()
            }
        }
    }
    
    private func openNotificationSettings() {
        // Universal way to open Notification settings on macOS
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        onComplete()
    }
}
