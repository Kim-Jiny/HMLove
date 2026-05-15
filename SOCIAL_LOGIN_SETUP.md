# 소셜 로그인 설정 가이드 (Google · Apple · Kakao)

코드 작업은 모두 끝났고, 아래는 **사용자가 직접 해야 하는 외부 콘솔/키 작업**입니다.

---

## 1. 서버 환경 변수 (`server/.env`)

```env
# 콤마 구분 (iOS / Android / Web 클라이언트 ID)
GOOGLE_CLIENT_IDS=ios-client-id.apps.googleusercontent.com,android-client-id.apps.googleusercontent.com,web-client-id.apps.googleusercontent.com

# 콤마 구분 (Bundle ID + Service ID)
APPLE_CLIENT_IDS=com.jiny.hmlove,com.jiny.hmlove.signin

# (Kakao 는 access token 검증을 카카오 서버에 위임하므로 서버 키 불필요)
```

---

## 2. Google 설정

### 2-1. Firebase Console
1. [Firebase Console](https://console.firebase.google.com) → `hmlove-251115` 프로젝트
2. **Authentication > Sign-in method > Google** 활성화
3. **Project Settings > General > Your apps > iOS app**
   - 새 `GoogleService-Info.plist` 다운로드 → `app/ios/Runner/GoogleService-Info.plist` 교체
   - 새 plist 에 `REVERSED_CLIENT_ID` 키가 추가되어 있어야 함
4. **Android app** 의 SHA-1 등록
   - 디버그: `cd app/android && ./gradlew signingReport` 의 `SHA1` 값
   - 릴리즈: 키스토어의 SHA-1
   - Firebase Console > Project Settings > Your apps > Android > "Add fingerprint"

### 2-2. iOS `Info.plist` 업데이트
`app/ios/Runner/Info.plist` 의 `REPLACE_WITH_REVERSED_CLIENT_ID` 를 **새 plist 의 `REVERSED_CLIENT_ID` 값**으로 교체.

예: `com.googleusercontent.apps.533381747710-abc123def456`

### 2-3. Web/Server Client ID
서버 검증용으로 별도 Web 클라이언트 ID 가 필요할 수 있음.
- [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → `hmlove-251115` 프로젝트
- "OAuth 2.0 Client IDs" 에서 iOS / Android / Web 각각의 Client ID 를 모두 `GOOGLE_CLIENT_IDS` 에 추가

---

## 3. Apple 설정 (iOS 전용)

### 3-1. Apple Developer
1. [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles
2. **Identifiers > App IDs > com.jiny.hmlove** 선택
   - "Sign In with Apple" Capability 체크 → Save
3. (선택, 서버 사이드 검증 강화용) **Service ID 생성**
   - Identifier: `com.jiny.hmlove.signin`
   - "Sign In with Apple" 활성화 → Configure
   - Domain: `love.jiny.shop`
   - Return URL: `https://love.jiny.shop/api/auth/social/apple/callback` (현재 서버는 콜백 URL 안 씀, 등록만)
4. (선택) **Keys > + > Sign in with Apple** → 키 생성, .p8 파일 + Key ID 보관
   - 토큰 만료 후 갱신 필요 시 사용. 지금 구현은 identity token 검증만 하므로 필수는 아님.

### 3-2. Xcode Capability
- Xcode 에서 Runner 타겟 > Signing & Capabilities > **+ Capability > Sign in with Apple**
- (이미 entitlements 파일에 추가해뒀으므로 자동 인식)

### 3-3. 환경변수
- `APPLE_CLIENT_IDS=com.jiny.hmlove`
- Service ID 도 만들었다면 `APPLE_CLIENT_IDS=com.jiny.hmlove,com.jiny.hmlove.signin`

---

## 4. Kakao 설정

### 4-1. 카카오 디벨로퍼스
1. [developers.kakao.com](https://developers.kakao.com) 로그인 → 내 애플리케이션 > 애플리케이션 추가
2. 앱 생성 후 **앱 키** 페이지에서 **네이티브 앱 키** 복사
3. **플랫폼 등록**
   - iOS: Bundle ID = `com.jiny.hmlove`
   - Android: 패키지명 = `com.jiny.hmlove`(applicationId 확인) + 키 해시
     - 디버그 키 해시: `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64`
     - 릴리즈: 본인 키스토어로 동일 명령
4. **카카오 로그인 > 활성화 ON**
5. **카카오 로그인 > 동의항목**: 닉네임 (필수), 이메일 (선택, 비즈앱 등록 안 했으면 선택만 가능)

### 4-2. iOS `Info.plist` 업데이트
`app/ios/Runner/Info.plist` 의 `kakaoREPLACE_WITH_NATIVE_APP_KEY` 를 **`kakao{네이티브 앱 키}`** 로 교체.

예: 네이티브 앱 키가 `a1b2c3d4e5f6` 면 → `kakaoa1b2c3d4e5f6`

### 4-3. Android `AndroidManifest.xml` 업데이트
`app/android/app/src/main/AndroidManifest.xml` 의 `kakaoREPLACE_WITH_NATIVE_APP_KEY` 도 같은 값으로 교체.

### 4-4. Flutter 빌드 시 키 주입
```bash
# 디버그 실행
flutter run --dart-define=KAKAO_NATIVE_APP_KEY=a1b2c3d4e5f6

# 릴리즈 빌드
flutter build ios --dart-define=KAKAO_NATIVE_APP_KEY=a1b2c3d4e5f6
flutter build apk --dart-define=KAKAO_NATIVE_APP_KEY=a1b2c3d4e5f6
```

또는 `app/dart_defines.json` (gitignore) 같은 파일을 만들어서 `--dart-define-from-file=dart_defines.json` 으로 주입하는 방법도 가능.

---

## 5. DB 마이그레이션 적용

```bash
cd server
docker compose up -d db   # DB 컨테이너 띄우기
npm run prisma:migrate    # 새 마이그레이션 (add_social_accounts) 적용
```

---

## 6. 동작 확인 체크리스트

### 신규 가입 흐름
- [ ] 로그인 화면 → 카카오/구글/애플 버튼 표시 (Apple 은 iOS 만)
- [ ] 버튼 탭 → 각 SDK 로그인 → 닉네임/생일 입력 화면 → 가입 완료 → 커플 연결 화면

### 기존 이메일 사용자가 같은 이메일로 소셜 로그인 시도
- [ ] "이미 가입된 이메일입니다" 다이얼로그 표시
- [ ] 다이얼로그 닫으면 이메일 칸에 자동 입력됨
- [ ] 비밀번호 로그인 → 더보기 > 계정 연동에서 해당 provider 연동
- [ ] 다음부터 같은 소셜 로그인 시 즉시 로그인됨

### 연동 해제
- [ ] 더보기 > 계정 연동 → 연동된 provider 옆 "해제" 버튼
- [ ] 비밀번호 없는 소셜 전용 계정은 마지막 provider 해제 차단됨

---

## 7. 트러블슈팅

| 증상 | 원인 / 확인 |
|---|---|
| Google 로그인 후 서버 401 | `GOOGLE_CLIENT_IDS` 에 클라이언트가 사용한 ID 가 포함됐는지. 토큰의 `aud` 클레임 확인 |
| Apple 로그인 자체가 안 뜸 | Xcode > Signing & Capabilities 에 Sign in with Apple 추가됐는지, 프로비저닝 프로파일 갱신했는지 |
| Kakao 로그인 후 콜백이 안 돌아옴 | iOS Info.plist / Android Manifest 의 `kakao{NATIVE_APP_KEY}` 가 정확한지 |
| 카카오 이메일이 비어있음 | 비즈앱 등록 안 됐거나 사용자가 이메일 동의 거부. 서버는 이 경우 placeholder 이메일을 자동 생성 |
| 카카오 디벨로퍼스 "유효하지 않은 키 해시" | 디버그/릴리즈 키스토어 모두 등록했는지. 디버그는 ~/.android/debug.keystore |
