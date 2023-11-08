.PHONY: install

input_conf="g script-message contact-sheet-close; script-message playlist-view-toggle\nc script-message playlist-view-close; script-message contact-sheet-toggle"

install:
	mkdir -p ${HOME}/.config/mpv/scripts \
	         ${HOME}/.config/mpv/script-modules \
	         ${HOME}/.config/mpv/script-opts

# Copy scripts
	install -m 0644 scripts/contact-sheet.lua \
	                scripts/gallery-thumbgen.lua \
					scripts/playlist-view.lua \
					${HOME}/.config/mpv/scripts/

# Copy script-opts
	install -m 0644 script-opts/contact_sheet.conf \
	                script-opts/gallery_worker.conf \
					script-opts/playlist_view.conf \
					${HOME}/.config/mpv/script-opts/

# Copy script-modules
	install -m 0644 script-modules/gallery.lua \
					${HOME}/.config/mpv/script-modules/

# Add configuration to input.conf
# to toggle between contact and gallery since they can not
# be used at the same time
	printf $(input_conf) >> ${HOME}/.config/mpv/input.conf

