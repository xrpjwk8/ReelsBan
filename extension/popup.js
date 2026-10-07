const $ = id => document.getElementById(id);
const services = { instagram: '인스타그램 릴스', youtube: '유튜브 쇼츠', tiktok: '틱톡' };
for (const [platform, label] of Object.entries(services)) {
  const section = document.createElement('section');
  section.className = 'service';
  section.innerHTML = `<div class="service-top"><h2>${label}</h2><input id="${platform}-enabled" type="checkbox" role="switch" aria-label="${label} 브레이크" checked></div><div class="service-usage"><span><strong id="${platform}-count">—</strong><span id="${platform}-total"> / 20개</span></span><span id="${platform}-remaining" class="remaining">불러오는 중</span></div><progress id="${platform}-progress" max="20" value="0" aria-label="${label} 사용량"></progress><div class="service-limit"><label for="${platform}-limit">하루 한도</label><div class="input-unit"><input id="${platform}-limit" type="number" min="1" max="500" step="1" required value="20"><span>개</span></div></div>`;
  $('services').append(section);
}
function render(state, settings = false) {
  $('day').textContent = state.day.slice(5).replace('-', '.');
  for (const platform of Object.keys(services)) {
    const service = state.services[platform];
    $(`${platform}-count`).textContent = service.count;
    $(`${platform}-total`).textContent = ` / ${service.limit}개`;
    $(`${platform}-progress`).max = service.limit;
    $(`${platform}-progress`).value = service.count;
    $(`${platform}-remaining`).textContent = service.enabled ? `${Math.max(0, service.limit - service.count)}개 남음` : '꺼짐';
    if (settings) {
      $(`${platform}-limit`).value = service.limit;
      $(`${platform}-enabled`).checked = service.enabled;
    }
  }
}
function error(message) { $('message').textContent = message; $('message').className = 'error'; }
async function request(message) {
  const result = await chrome.runtime.sendMessage(message);
  if (!result?.ok) throw new Error(result?.error || '확장 프로그램을 다시 열어 주세요.');
  return result.state;
}
$('settings').addEventListener('submit', async event => {
  event.preventDefault();
  $('save').disabled = true;
  try {
    const values = Object.fromEntries(Object.keys(services).map(platform => [platform, {
      limit: Number($(`${platform}-limit`).value), enabled: $(`${platform}-enabled`).checked
    }]));
    render(await request({ type: 'settings', services: values }), true);
    $('message').className = '';
    $('message').textContent = '저장했어요.';
  } catch (e) { error(e.message); }
  finally { $('save').disabled = false; }
});
request({ type: 'get' }).then(state => { render(state, true); $('save').disabled = false; }).catch(e => error(e.message));
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.state?.newValue?.services) render(changes.state.newValue);
});
