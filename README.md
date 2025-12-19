# Kaos Mühendisliği Projesi

Bu repo, Chaos Mesh kullanılarak Kubernetes üzerinde çalışan bir Flask uygulamasında chaos engineering deneylerini içerir.

## Proje Amacı
Hocanın verdiği demo uygulamayı temel alarak özgün bir chaos deneyi tasarlamak:
- Workflow kullanarak zincirleme kaos senaryosu oluşturma
- Ağ gecikmesi, pod öldürme ve CPU stresi kombinasyonu

## Kullanılan Teknolojiler
- Kubernetes (Minikube/Kind)
- Chaos Mesh
- Docker + Flask demo app

## Özgün Deney: Disaster Simulation Workflow

Sırayla:
1. 2 saniye ağ gecikmesi (NetworkChaos)
2. Rastgele bir backend pod'unun öldürülmesi (PodChaos)
3. Backend pod'lara %80 CPU yükü (StressChaos)

### Workflow YAML
`08-disaster-workflow.yaml` dosyasında tanımlı.

### Deney Sonuçları
- Ağ gecikmesi sırasında latency ~2000ms'ye çıktı
- Pod kill sonrası Kubernetes otomatik recovery yaptı (~15-20 saniye)
- CPU stress altında yanıtlar yavaşladı ama uygulama çöktü

## Screenshot'lar
Tüm deney kanıtları `screenshots/` klasöründe:

- Chaos Dashboard genel görünüm
- Workflow çalışırken ve bittikten sonra
- Pod kill öncesi/sonrası pod listesi
- Latency test çıktıları

## Kurulum ve Çalıştırma
1. Chaos Mesh kurulumu: Helm ile
2. Uygulama deploy: `kubectl apply -f k8s/deployment.yaml`
3. Workflow çalıştırma: `kubectl apply -f 08-disaster-workflow.yaml`

## Teslim Edilen Zip
`screenshots.zip` dosyası tüm ekran görüntülerini içerir.

Teşekkürler!