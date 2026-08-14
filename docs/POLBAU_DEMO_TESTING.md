# polbau-demo — запуск и чеклист тестирования

Flavor: `polbauDemo`  
Firestore doc: `mobile_configs/polbau-demo`  
Package (Android): `com.polbau.polbau_demo`  
Bundle ID (iOS): `com.polbau.polbau_demo`

---

## Предварительные условия

- [ ] Flutter SDK установлен (`flutter doctor` без критичных ошибок)
- [ ] Firestore doc `polbau-demo` содержит:
  - `showSeletorPage: true`
  - `selectorItems` (минимум 1 элемент с `name`, `image`, `logo`, `redirection_url`)
  - `webviewUrl`, `backendUrl`, `companyId`, `version`
- [ ] Доступ к Firebase project `development-417611`, database `skanuj-wygrywaj`
- [ ] Для iOS: Xcode + CocoaPods (`pod install` в `ios/`)

---

## Как запустить

### Android (эмулятор или девайс)

```bash
# Список устройств
flutter devices

# Запуск
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# Или через скрипт
./run_flavor.sh polbauDemo android
```

Если конфликт package с другим flavor — скрипт `run_flavor.sh` удалит старые APK.

### iOS (симулятор)

```bash
flutter devices

flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# Или
./run_flavor.sh polbauDemo ios
```

Первый запуск может занять несколько минут (pod install + Xcode build).

### Debug с принудительным обновлением конфига

В debug режиме конфиг рефрешится из Firestore:

```bash
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo
```

Для очистки кеша конфига — переустановить приложение или удалить данные app.

### Release-сборка (smoke test)

```bash
# Android
flutter build apk --flavor polbauDemo --dart-define=FLAVOR=polbauDemo --release

# iOS simulator
flutter build ios --flavor polbauDemo --dart-define=FLAVOR=polbauDemo --simulator --debug
```

---

## Чеклист: Mall Selector

### Общее

- [ ] Приложение стартует без crash
- [ ] В логах: `[CompanyMapping] Using company ID from flavor: polbau-demo` (или из Firestore)
- [ ] Показывается экран **«Wybierz swoje / Centrum handlowe»**
- [ ] Отображаются все карточки из `selectorItems`
- [ ] У каждой карточки: фон, лого, название (uppercase)
- [ ] Placeholder/error при недоступных картинках — карточка не ломается

### Android

- [ ] Status bar: светлые иконки на тёмном фоне
- [ ] Safe area: контент не под status bar / gesture nav
- [ ] Ripple при тапе на карточку
- [ ] Hardware **Back** на селекторе → выход из приложения

### iOS

- [ ] Notch / Dynamic Island: заголовок не обрезан
- [ ] Home indicator: нижний padding корректный
- [ ] Scroll списка с bounce
- [ ] Hardware жестов back на селекторе — выход (home screen)

---

## Чеклист: WebView после выбора мола

- [ ] Тап на карточку → открывается WebView
- [ ] URL = `redirection_url` выбранного мола (не `webviewUrl`)
- [ ] Лог: `[WebViewScreen] Loading ... URL: <redirection_url>`
- [ ] Страница логина/приложения загружается
- [ ] **Back** (Android) → history WebView, затем выход (не возврат на селектор)
- [ ] На iOS после выбора нет swipe-back на селектор (ожидаемо: `pushReplacement`)

Пример URL (Ostrovia):

```
https://login.2take.it/?company_name=ch-ostrovia&legacy=true&d=0
```

---

## Чеклист: Fallback без селектора

Проверить в Firestore (или временно для теста):

- [ ] `showSeletorPage: false` → сразу WebView с `webviewUrl`
- [ ] `showSeletorPage: true` + пустой `selectorItems` → WebView с `webviewUrl`

---

## Чеклист: Offline / Cache

- [ ] Первый запуск online → селектор виден
- [ ] Закрыть app, включить airplane mode, перезапустить
- [ ] Селектор показывается из SharedPreferences cache
- [ ] Карточки без сети: placeholder/error на картинках

---

## Чеклист: Логин

> Тестировать **после выбора мола** в WebView. Для каждого способа: успешный вход, ошибка (отмена), повторный вход после logout.

### Email

- [ ] На экране логина есть форма входа по email (и пароль / magic link — как на web)
- [ ] Ввод валидного email + пароля → успешный вход, редирект в приложение
- [ ] Невалидный email / неверный пароль → понятная ошибка на странице
- [ ] После входа сессия сохраняется (перезапуск app → остаётся залогинен)

### Google

- [ ] Кнопка Google на странице логина открывает **native** Google Sign-In (не только web popup)
- [ ] Выбор аккаунта → успешный вход в приложение
- [ ] В логах: `[WEBVIEW] ... Company (Google Auth): polbau-demo` и `GoogleSignIn initialized`
- [ ] Отмена Google picker → возврат на экран логина без crash
- [ ] ⚠️ Для polbau нужен entry в `_googleAuthClientIds` + Android OAuth client с SHA-1

### Facebook

- [ ] Кнопка Facebook триггерит **native** Facebook login (`flutter_facebook_auth`)
- [ ] Успешный login → токен передаётся в WebView, пользователь залогинен
- [ ] Отмена / ошибка → сообщение на странице, app не падает
- [ ] App ID в native: `683312195062841`
- [ ] ⚠️ Android: `facebook_client_token` в `strings.xml` не должен быть placeholder

### Телефон (SMS / OTP)

- [ ] На экране логина доступен вход по номеру телефона
- [ ] Ввод номера → отправка SMS / OTP (или переход на шаг кода)
- [ ] Ввод корректного кода → успешный вход
- [ ] Неверный код → ошибка, можно запросить повторно
- [ ] На **реальном девайсе** (SMS на симуляторе может не работать)

### Apple (iOS, если есть на странице)

- [ ] Sign in with Apple открывается нативно
- [ ] Успешный вход → пользователь в приложении

---

## Чеклист: Скан чеков (paragony)

> Скан тестировать **на реальном девайсе** с камерой. На iOS Simulator камера недоступна — только gallery fallback.

### Запуск скана

- [ ] После логина доступна функция добавления / скана чека (кнопка «Skanuj», «Dodaj paragon» и т.п.)
- [ ] Тап на scan → нативный диалог **Aparat / Camera** и **Galeria / Gallery**
- [ ] В логах при scan: `FPK: launching camera` или `FPK: launching gallery`

### Камера

- [ ] **Aparat** → открывается системная камера (rear camera)
- [ ] Разрешение на камеру запрашивается при первом использовании (iOS + Android)
- [ ] Фото чека → загружается в web app, появляется preview / success
- [ ] Отмена камеры → возврат без crash, можно повторить

### Галерея

- [ ] **Galeria** → открывается photo picker
- [ ] Выбор фото чека из галереи → upload / обработка в web app
- [ ] Разрешение на photo library (iOS `NSPhotoLibraryUsageDescription`)

### Обработка чека

- [ ] После upload чек распознаётся / принимается backend'ом (success UI)
- [ ] Нечитаемое / невалидное фото → ошибка от сервера, можно загрузить снова
- [ ] Повторный scan второго чека работает

### Bridge APP2TI (если web вызывает напрямую)

- [ ] `window.APP2TI.startScan()` из WebView открывает тот же camera/gallery flow
- [ ] `window.APP2TI.startScanForId(id)` — scan с привязкой к id

---

## Чеклист: FCM (опционально)

- [ ] Разрешение на push (iOS первый запуск)
- [ ] Secret gesture: 7 быстрых тапов в правом верхнем углу → dialog с FCM token
- [ ] Token копируется в clipboard

---

## Чеклист: Прочее

- [ ] `tel:` / `mailto:` / `sms:` открывают системные приложения
- [ ] Нет регрессии: другие flavors (`galeriaKazimierz`) стартуют как раньше

---

## Полезные логи

| Лог | Ожидание |
|-----|----------|
| `[Flavor] Initialized: Moja Galeria (FlavorType.polbauDemo)` | flavor ок |
| `[ConfigService] Fetching secure config for: polbau-demo` | Firestore doc |
| `[WebViewScreen] Loading ... URL:` | правильный URL после выбора |
| `[WEBVIEW] Flavor: ... Company (UI): polbau-demo` | config ок |
| `GoogleSignIn: idToken len=...` | Google login прошёл |
| `flutter_facebook_tokens` / `[NATIVE->WEB][FB]` | Facebook login прошёл |
| `FPK: launching camera` / `FPK: launching gallery` | scan чека запущен |

---

## Известные ограничения (текущая версия)

1. **iOS `Info.plist`** — общий для всех flavors; Google/Facebook IDs могут быть от galeria
2. **`ios/Runner/polbauDemo/GoogleService-Info.plist`** — заменить на plist с `BUNDLE_ID = com.polbau.polbau_demo`
3. **Android `google-services.json`** — нужен реальный `appId` + OAuth client для `com.polbau.polbau_demo`
4. **Dart `_googleAuthClientIds`** — добавить `'polbau-demo'` для корректного Google Auth
5. **Facebook Android token** — `REPLACE_WITH_CLIENT_TOKEN` в `strings.xml`

---

## Быстрая команда (copy-paste)

```bash
# Android
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# iOS
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo
```
