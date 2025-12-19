# Kaos Mühendisliği Projesi

Bu repo, Chaos Mesh kullanılarak Kubernetes üzerinde çalışan bir Flask uygulamasında chaos engineering deneylerini içerir.

## Proje Amacı
Hocanın verdiği demo uygulamayı temel alarak özgün bir chaos deneyi tasarlamak:
- Workflow kullanarak zincirleme kaos senaryosu oluşturma
- Ağ gecikmesi, pod öldürme ve CPU stresi kombinasyonu

## Kullanılan Teknolojiler
- Kubernetes cluster: Minikube (local)
- Chaos Mesh
- Docker + Flask demo app

## Özgün Deney: Disaster Simulation Workflow

Zincirleme senaryo (Serial):
1. Frontend → Backend trafiğine 2000ms gecikme (NetworkChaos)
2. Rastgele bir backend pod'unun öldürülmesi (PodChaos)
3. Backend pod'lara %80 CPU yükü (StressChaos)

### Workflow YAML
`08-disaster-workflow.yaml` dosyasında tanımlı.

### Deney Sonuçları ve Gözlemler
- **Workflow genel olarak başarıyla tamamlandı** (`workflow accomplished`).
- **Pod kill başarılı oldu**: Backend pod’lardan biri öldürüldü, Kubernetes otomatik olarak restart etti (pod'ların RESTARTS değeri 1'e çıktı). Recovery hızlı ve sorunsuz gerçekleşti.
- **CPU stress etkili oldu**: Yanıt sürelerinde yavaşlama gözlendi, ancak uygulama çökmedi.
- **Network delay kısmen etkili olmadı**: Local cluster (Minikube) ortamında "unable to flush ip sets" hatası nedeniyle latency artışı tam gözlenmedi. Bu, Chaos Mesh'in NetworkChaos özelliğinin local ortam kısıtlamalarından kaynaklanan bilinen bir sorunu.
- Sistem genel olarak **dayanıklı** çıktı: Pod kaybına rağmen hizmet kesintisi minimumdu.

## Screenshot'lar
Tüm deney kanıtları `screenshots/` klasöründe ve `screenshots.zip` dosyasında:

- `01-dashboard-overview.png`: Chaos Dashboard ana sayfa
- `02-workflow-running.png`: Workflow çalışırken topology
- `03-workflow-finished.png`: Workflow tamamlandı (events sekmesi)
- `04-pod-after-recovery.png` ve `05-pod-restart-evidence.png`: Pod kill sonrası restart kanıtı
- `06-network-delay-attempt.png`: NetworkChaos denemesi ve hatalar
- `07-describe-workflow-finished.png`: kubectl describe workflow çıktısı
- `08-chaos-events.png`: kubectl get events çıktısı

## Ek Dosyalar
- `chaos-rbac.yaml`: Chaos Dashboard'a erişim için kullanılan RBAC tanımı

## Kurulum ve Çalıştırma
1. Chaos Mesh kurulumu: Helm ile (`helm install chaos-mesh ...`)
2. Uygulama deploy: `kubectl apply -f k8s/deployment.yaml`
3. Dashboard erişimi: `kubectl port-forward ...` ve token ile login (`chaos-rbac.yaml` uygulanarak)
4. Workflow çalıştırma: `kubectl apply -f 08-disaster-workflow.yaml`

## Sonuç
Proje kapsamında Chaos Mesh Workflow özelliği kullanılarak karmaşık bir kaos senaryosu tasarlandı ve çalıştırıldı. Kubernetes'in self-healing yetenekleri gözlemlendi. Local ortamın NetworkChaos üzerindeki kısıtlamaları fark edildi ve raporlandı.

Teslim edilen zip dosyası tüm ekran görüntülerini içermektedir.

Teşekkürler!