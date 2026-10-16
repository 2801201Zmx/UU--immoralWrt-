'use strict';
'require form';
'require view';
'require poll';
'require rpc';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

function getServiceStatus() {
	return L.resolveDefault(callServiceList('uugamebooster'), {}).then(function(res) {
		var instances = res['uugamebooster'] && res['uugamebooster']['instances'];
		if (instances) {
			for (var key in instances) {
				if (Object.prototype.hasOwnProperty.call(instances, key) &&
				    instances[key] && instances[key].running)
					return true;
			}
		}
		return false;
	});
}

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('uugamebooster', _('UU Game Accelerator'),
			_('A paid game acceleration service. After enabling, use the mobile UU Host Accelerator APP to bind this router and select the console to accelerate.'));

		s = m.section(form.GridSection, '_status', _('Status'));
		s.render = function() {
			return E('div', { class: 'cbi-section' }, [
				E('p', { id: 'uugamebooster_status' }, _('Collecting data...'))
			]);
		};

		s = m.section(form.TypedSection, 'uugamebooster', _('Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = '0';
		o.rmempty = false;

		s = m.section(form.GridSection, '_qrcode', _('QR Code'));
		s.render = function() {
			return E('div', { class: 'cbi-section' }, [
				E('p', {}, _('Scan the QR code to download and bind the UU Host Accelerator APP:')),
				E('p', { id: 'uugamebooster_qcode' }, [
					E('img', { src: '/uugamebooster/uuios.png', height: '300', style: 'margin-right: 10px;' }),
					E('img', { src: '/uugamebooster/uuandriod.png', height: '300' })
				])
			]);
		};

		poll.add(function() {
			return getServiceStatus().then(function(running) {
				var node = document.getElementById('uugamebooster_status');
				if (node) {
					if (running) {
						node.innerHTML = '<strong><span style="color: green;">' + _('UU GameAcc') + ' &middot; ' + _('RUNNING') + '</span></strong>';
					} else {
						node.innerHTML = '<strong><span style="color: red;">' + _('UU GameAcc') + ' &middot; ' + _('NOT RUNNING') + '</span></strong>';
					}
				}
			});
		}, 3);

		return m.render();
	}
});
