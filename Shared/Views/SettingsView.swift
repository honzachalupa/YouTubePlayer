import SwiftUI
import SwiftCore

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            AboutAppView(
                developerId: 1557529575,
                developerName: "Jan Chalupa",
                developerEmail: "me@janchalupa.dev",
                developerWebsite: "https://www.janchalupa.dev/",
                storeCountryCode: "cz",
                privacyPolicy: privacyPolicyString,
                termsOfService: termsOfServiceString
            )
            .navigationTitle("About this app")
        }
    }
}

#Preview {
    SettingsView()
}

let privacyPolicyString = """
## 1. Introduction

This Privacy Policy describes how the My Happy Thoughts app ("the App") handles data and privacy considerations. This App allows users to create and manage personal events and thoughts.

## 2. Data Collection and Usage

The My Happy Thoughts app:

- Does not collect or store any personal information beyond what you enter
- Does not track user activity for analytics purposes
- Does not use cookies or similar tracking technologies
- Does not share your personal data with third parties

## 3. Data Storage

The App stores data in the following ways:

- Your events, notes, and thoughts are stored using SwiftData
- App data is synced across your devices using iCloud

While iCloud is used for data storage and synchronization, this data is only accessible to you through your Apple ID. No data is shared with the developer except as required for App functionality.

## 4. Third-Party Services

The App integrates with the following third-party services:

- Apple iCloud: For syncing your data across devices
- App Store: For displaying developer's other applications

These services have their own privacy policies and terms of use. We recommend reviewing their respective policies.

## 5. User Rights and Control

You have full control over your data within the App:

- You can delete any event or thought at any time
- You can export or delete all your data
- You can manage your content organization through the app's features

## 6. Children's Privacy

The App is not directed to children under the age of 13, and we do not knowingly collect personal information from children under 13.

## 7. Changes to This Privacy Policy

This Privacy Policy may be updated from time to time. Users will be notified of any changes by updating the "Last Updated" date at the bottom of this policy.

## 8. Contact Information

If you have any questions about this Privacy Policy, please contact me@janchalupa.dev.

---

Last Updated: July 7, 2025
"""

let termsOfServiceString = """
## 1. Introduction

These Terms of Service ("Terms") govern your access to and use of the My Happy Thoughts app ("the App"), a SwiftUI-based iOS application that enables users to track and manage personal events and thoughts. By downloading, installing, or using the App, you agree to be bound by these Terms.

## 2. User Responsibilities

As a user of the App, you are responsible for:

- All content you create within the App
- Ensuring your use of the App complies with applicable laws and regulations
- Managing your events and thoughts
- Maintaining the security of your device and Apple ID

## 3. Acceptable Use

You agree to use the App only for lawful purposes. You shall not use the App to:

- Store content that is illegal, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable
- Attempt to reverse engineer or bypass any security measures in the App
- Use automated methods to access or use the App in a manner that exceeds reasonable use
- Redistribute, sell, or lease access to the App to third parties

## 4. Intellectual Property

The App, including its code, design, and functionality, is owned by the developer and protected by intellectual property laws. You may not copy, modify, distribute, sell, or lease any part of the App without explicit permission.

## 5. Disclaimer of Warranties

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT ANY WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. TO THE FULLEST EXTENT PERMITTED BY LAW, WE DISCLAIM ALL WARRANTIES, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

We do not warrant that the App will function without interruption or errors, or that any defects will be corrected.

## 6. Limitation of Liability

TO THE FULLEST EXTENT PERMITTED BY LAW, IN NO EVENT SHALL THE DEVELOPER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS APP, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## 7. Third-Party Services

The App depends on the following third-party services:

- Apple iCloud for data synchronization across devices

Your use of these services through the App is governed by their respective terms and policies.

## 8. Updates to Terms

These Terms may be modified at any time. Notice of significant changes will be provided by updating the version date of these Terms. Your continued use of the App after such modifications constitutes your acceptance of the revised Terms.

## 9. Governing Law

These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which the primary maintainer resides, without regard to its conflict of law provisions.

## 10. Contact Information

If you have any questions about these Terms, please contact me@janchalupa.dev.

---

Last Updated: July 7, 2025
"""
