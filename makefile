build:
	docker build --target jodconverter-base . -t efun/jodconverter-cjk:base
	#docker build --target gui . -t efun/jodconverter-cjk:gui
	docker build --target rest . -t efun/jodconverter-cjk:rest

#push:
#	docker push eugenmayer/jodconverter:base
#	docker push eugenmayer/jodconverter:gui
#	docker push eugenmayer/jodconverter:rest

start-gui: stop
	docker run --name jodconverter-spring -m 512m --rm -p "8080:8080" efun/jodconverter-cjk:gui

start-rest: stop
	docker run --name jodconverter-rest -m 512m --rm -p 8080:8080 efun/jodconverter-cjk:rest

stop:
	docker stop --name jodconverter-rest > /dev/null 2>&1 || true
	docker stop --name jodconverter-spring > /dev/null 2>&1 || true
