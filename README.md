# SIP alerts

## Настройка development environment

> Подразумевается, что Docker установлен по [инструкции с официального сайта](https://docs.docker.com/engine/install). Корректная работа других версий (из snap, например) не гарантируется 

1. Открыть в VS Code папку проекта
2. Открыть Command Palette (F1), выбрать **Dev Containers: Reopen in Container**
3. Для проверки работы Prometheus и AlertManager в браузере откройте localhost по портам 9090 и 9093
4. Для проверки отсылки тестового алерта отправьте GET на http://localhost:9191/\_\_last_request\_\_
5. Для проверки дерева супервизоров можете воспользоваться eunit и вручную с помощью dummy_server:crash(Название модуля/супервизора).
6. Для проверки http-api можно запустить через rebar3 shell (смотреть вывод в терминал) либо запустить тесты соот. модулей
7. Profit!
