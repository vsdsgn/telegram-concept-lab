# concept-20261122-121705-7a1e

## Original user request

Reaction Wheel — радиальное меню реакций для Telegram.

Проблема: выбор реакции на сообщение недостаточно выразителен.

Сценарий: долгий тап по сообщению открывает полукруг из 6 эмодзи. Пользователь, не отпуская палец, перемещается между ними и выбирает реакцию.

Анимация: эмодзи появляются каскадом с пружинной анимацией; выбранный увеличивается, остальные слегка отдаляются. Лёгкий haptic при изменении выбора.

Исключения: отмена жеста, отпускание вне зоны, размещение у края экрана, Reduced Motion, VoiceOver/TalkBack.

Сделайте нативные работающие прототипы для iOS и Android. Поведение единое, реализация учитывает особенности платформ. Добавьте dark/light mode, демонстрационные сообщения, инструкции сборки и проверки.м


## Collaboration contract

1. Claude produces concrete interaction design for iOS AND Android.
2. Codex critiques the proposed UX and implements both native apps.
3. Claude reviews BOTH codebases; Codex fixes issues and checks visual fidelity.
4. Each platform runs and tests independently. No Telegram backend integration is assumed.
5. The idea and code are PUBLIC; do not use secrets, sensitive or employer assets.
