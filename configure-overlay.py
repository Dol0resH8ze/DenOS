#!/usr/bin/env python3
"""Generate repetitive desktop configuration without external dependencies."""
import json
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent / 'overlay'

def write(path, text):
    dest = ROOT / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding='utf-8')

def prop(name, typ, value):
    if typ == 'bool':
        value = 'true' if value else 'false'
    return f'<property name="{escape(name)}" type="{typ}" value="{escape(str(value))}"/>'

def channel(name, content):
    write(f'etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/{name}.xml', f'<?xml version="1.0" encoding="UTF-8"?>\n<channel name="{name}" version="1.0">{content}</channel>\n')

channel('xsettings', '<property name="Net" type="empty">' + prop('ThemeName','string','Arc-Dark') + prop('IconThemeName','string','Adwaita') + '</property><property name="Gtk" type="empty">' + prop('FontName','string','DejaVu Sans 10') + prop('ApplicationPreferDarkTheme','bool',True) + prop('RecentFilesMaxAge','int',0) + prop('RecentFilesEnabled','bool',False) + '</property><property name="Xft" type="empty">' + prop('Antialias','int',1) + prop('Hinting','int',1) + prop('HintStyle','string','hintslight') + prop('RGBA','string','rgb') + '</property>')
channel('xfwm4','<property name="general" type="empty">' + ''.join(prop(k,t,v) for k,t,v in [('theme','string','Arc-Dark'),('title_font','string','DejaVu Sans Bold 10'),('button_layout','string','O|HMC'),('workspace_count','int',2),('use_compositing','bool',True),('show_frame_shadow','bool',True),('cycle_preview','bool',True),('box_move','bool',False)]) + '</property>')
channel('xfce4-desktop','<property name="desktop-icons" type="empty">' + prop('style','int',0) + '</property><property name="backdrop" type="empty"><property name="screen0" type="empty"><property name="monitorVirtual-1" type="empty"><property name="workspace0" type="empty">' + prop('last-image','string','/usr/share/denos/wallpaper.svg') + prop('image-style','int',5) + '</property></property></property></property>')
channel('xfce4-session','<property name="general" type="empty">' + prop('SaveOnExit','bool',False) + prop('PromptOnLogout','bool',True) + '</property>')
channel('thunar',''.join(prop(k,t,v) for k,t,v in [('misc-single-click','bool',False),('misc-volume-management','bool',False),('last-view','string','ThunarIconView'),('last-window-width','int',960),('last-window-height','int',640)]))

def array(name, values, typ='int'):
    return f'<property name="{name}" type="array">'+''.join(f'<value type="{typ}" value="{v}"/>' for v in values)+'</property>'

plugins = [(1,'applicationsmenu'),(2,'tasklist'),(3,'separator'),(4,'systray'),(5,'clock'),(6,'actions'),(10,'launcher'),(11,'launcher'),(12,'launcher'),(13,'launcher'),(14,'launcher'),(15,'launcher')]
contents = '<property name="configver" type="int" value="2"/>'
contents += '<property name="panels" type="array"><value type="int" value="1"/><value type="int" value="2"/>'
contents += '<property name="panel-1" type="empty">'+''.join(prop(k,t,v) for k,t,v in [('position','string','p=6;x=0;y=0'),('position-locked','bool',True),('size','uint',34),('length','double',100),('length-adjust','bool',False),('background-style','uint',0)])+array('plugin-ids',[1,2,3,4,5,6])+'</property>'
contents += '<property name="panel-2" type="empty">'+''.join(prop(k,t,v) for k,t,v in [('position','string','p=10;x=0;y=0'),('position-locked','bool',True),('size','uint',52),('length','double',30),('length-adjust','bool',True),('autohide-behavior','uint',0),('background-style','uint',0)])+array('plugin-ids',[10,11,12,13,14,15])+'</property></property>'
contents += '<property name="plugins" type="empty">'
for number, name in plugins:
    contents += f'<property name="plugin-{number}" type="string" value="{name}">'
    if number == 1:
        contents += prop('show-button-title','bool',True)+prop('button-title','string','DenOS')+prop('show-button-icon','bool',True)+prop('button-icon','string','/usr/share/denos/denos.svg')
    if number == 2:
        contents += prop('show-handle','bool',False)+prop('show-labels','bool',True)+prop('flat-buttons','bool',True)
    if number == 3:
        contents += prop('expand','bool',True)+prop('style','uint',0)
    if number == 5:
        contents += prop('digital-format','string','%a, %d %b  ·  %H:%M')+prop('mode','uint',2)
    if number >= 10:
        contents += array('items',[f'{number}.desktop'],'string')
    contents += '</property>'
contents += '</property>'
channel('xfce4-panel',contents)

entries = [
    ('DenOS','denos-hub','/usr/share/denos/denos.svg'),
    ('Firefox','firefox-esr','firefox-esr'),
    ('Files','thunar','system-file-manager'),
    ('Terminal','xfce4-terminal','utilities-terminal'),
    ('Notes','mousepad','accessories-text-editor'),
    ('Settings','xfce4-settings-manager','preferences-desktop'),
]
for i,(name,cmd,icon) in enumerate(entries,10):
    write(f'etc/skel/.config/xfce4/panel/launcher-{i}/{i}.desktop',f'[Desktop Entry]\nType=Application\nName={name}\nExec={cmd}\nIcon={icon}\nTerminal=false\nStartupNotify=true\n')

write('etc/skel/.config/gtk-3.0/settings.ini','[Settings]\ngtk-theme-name=Arc-Dark\ngtk-icon-theme-name=Adwaita\ngtk-application-prefer-dark-theme=true\ngtk-font-name=DejaVu Sans 10\ngtk-recent-files-enabled=false\n')
write('etc/skel/.gtkrc-2.0','gtk-theme-name="Arc-Dark"\ngtk-icon-theme-name="Adwaita"\ngtk-font-name="DejaVu Sans 10"\n')
write('etc/skel/.config/xfce4/terminal/terminalrc','[Configuration]\nFontName=DejaVu Sans Mono 11\nColorForeground=#d9e6ee\nColorBackground=#10151d\nColorCursor=#a6e5d3\nMiscMenubarDefault=FALSE\nMiscToolbarDefault=FALSE\nBackgroundMode=TERMINAL_BACKGROUND_SOLID\nScrollingLines=5000\n')
write('etc/profile.d/denos-privacy.sh','# Session history is disabled by default.\nexport HISTFILE=/dev/null\nexport HISTSIZE=0\nexport GTK_THEME=Arc-Dark\n')
write('etc/systemd/journald.conf.d/denos.conf','[Journal]\nStorage=volatile\nRuntimeMaxUse=32M\n')
write('etc/lightdm/lightdm-gtk-greeter.conf','[greeter]\ntheme-name=Arc-Dark\nicon-theme-name=Adwaita\nfont-name=DejaVu Sans 10\nbackground=/usr/share/denos/wallpaper.svg\nuser-background=false\ndefault-user-image=/usr/share/denos/denos.svg\n')

policies = {'policies': {
    'DisableTelemetry':True,
    'DisableFirefoxStudies':True,
    'DisablePocket':True,
    'DisableFormHistory':True,
    'OfferToSaveLogins':False,
    'DontCheckDefaultBrowser':True,
    'OverrideFirstRunPage':'',
    'OverridePostUpdatePage':'',
    'Homepage':{'URL':'file:///usr/share/denos/start.html','StartPage':'homepage'},
    'EnableTrackingProtection':{'Value':True,'Locked':False,'Cryptomining':True,'Fingerprinting':True,'Category':'strict'},
    'Preferences':{
        'privacy.privatebrowsing.autostart':{'Value':True,'Status':'default'},
        'browser.search.suggest.enabled':{'Value':False,'Status':'default'},
        'browser.urlbar.suggest.searches':{'Value':False,'Status':'default'},
        'network.prefetch-next':{'Value':False,'Status':'default'},
        'network.dns.disablePrefetch':{'Value':True,'Status':'default'},
        'network.http.speculative-parallel-limit':{'Value':0,'Status':'default'},
        'network.captive-portal-service.enabled':{'Value':False,'Status':'default'},
        'browser.newtabpage.activity-stream.feeds.telemetry':{'Value':False,'Status':'locked'},
        'browser.newtabpage.activity-stream.showSponsored':{'Value':False,'Status':'locked'},
        'browser.newtabpage.activity-stream.showSponsoredTopSites':{'Value':False,'Status':'locked'},
    }
}}
for path in ['etc/firefox/policies/policies.json','usr/share/firefox-esr/distribution/policies.json']:
    write(path,json.dumps(policies,indent=2)+'\n')

write('usr/share/denos/start.html','''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>DenOS · A quieter digital life</title><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:radial-gradient(at 75% 80%,#183c3c,#0c111c 70%);color:#edf4f7;font:16px/1.7 system-ui}main{max-width:640px;padding:60px}img{width:60px}small{color:#9de1ce;letter-spacing:3px}h1{font-size:64px;line-height:1.06;letter-spacing:-3px;margin:25px 0}p{color:#a6b3c3}aside{border:1px solid #33414d;padding:22px;border-radius:12px;margin-top:35px}b{color:#b9e8db}</style><main><img src="denos.svg" alt="DenOS"><p><small>YOUR SPACE. YOUR RULES.</small></p><h1>A quieter place<br>to start.</h1><p>Welcome to Firefox on DenOS. Private browsing and strict tracking protection are defaults. Firefox telemetry and studies are disabled by policy.</p><aside><b>Ready when you are.</b><br>Networking starts off. Open the DenOS Privacy Center from the dock to enable internet access, then enter an address above.</aside><p>Private browsing does not make you anonymous online. Downloads and bookmarks can remain on any disk you choose to use.</p></main></html>''')
print('DenOS desktop configuration generated.')
