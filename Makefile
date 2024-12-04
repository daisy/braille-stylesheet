EPUB := valentin-hauy.epub
BRF := $(patsubst %.epub,result/%.brf,$(EPUB))
PIPELINE_VERSION := 1.14.20
MOUNT_POINT := /mnt
PORT=8181

.PHONY : run-testsuite
run-testsuite : $(BRF)

$(BRF) : result/%.brf : %.epub bana.css | pipeline-up
	test "$$(                                                                   \
	    docker container inspect -f '{{.State.Running}}' pipeline 2>/dev/null   \
	)" = true;                                                                  \
	docker_mode=$$?;                                                            \
	if [ $${docker_mode} = 0 ]; then                                            \
	    network_option="--link pipeline";                                       \
	    host_option="--host http://pipeline";                                   \
	    mount_point="$(MOUNT_POINT)";                                           \
	else                                                                        \
	    network_option="--network host";                                        \
	    host_option="--host http://localhost";                                  \
	    mount_point="$(CURDIR)";                                                \
	fi &&                                                                       \
	eval                                                                        \
	docker run --name cli                                                       \
	           --rm                                                             \
	           $${network_option}                                               \
	           -v "'$(CURDIR):$${mount_point}:rw'"                              \
	           --entrypoint /opt/daisy-pipeline2/cli/dp2                        \
	           daisyorg/pipeline:$(PIPELINE_VERSION)                            \
	           $${host_option}                                                  \
	           --starting false                                                 \
	           epub3-to-pef --persistent                                        \
	                        --output "'$${mount_point}'"                        \
	                        --source "'$${mount_point}/$<'"                     \
	                        --output-file-format "'(locale:en-US)(pad:BEFORE)'" \
	                        --stylesheet "'$${mount_point}/$(word 2,$^)'";      \
	if ! [ -e "$@" ]; then                                                      \
	    if [ $${docker_mode} = 0 ]; then                                        \
	        docker logs pipeline;                                               \
	    fi;                                                                     \
	    exit 1;                                                                 \
	fi

bana.css :
	git checkout bana -- $@
	git restore --staged $@

.PHONY : get-latest-bana-css
get-latest-bana-css :
	$(MAKE) -B bana.css

valentin-hauy.epub :
	curl -L "https://dl.daisy.org/samples/epub/$(notdir $@)" >$@

.PHONY : clean
clean :
	rm -rf result

.PHONY : pipeline-up
pipeline-up :
	if ! curl localhost:$(PORT)/ws/alive >/dev/null 2>/dev/null;        \
	then                                                                \
	    docker run --name pipeline                                      \
	               -d                                                   \
	               -e PIPELINE2_WS_HOST=0.0.0.0                         \
	               -e PIPELINE2_WS_PORT=$(PORT)                         \
	               -e PIPELINE2_WS_LOCALFS=true                         \
	               -e PIPELINE2_WS_AUTHENTICATION=false                 \
	               -p $(PORT):$(PORT)                                   \
	               -v "$(CURDIR):$(MOUNT_POINT):rw"                     \
	               daisyorg/pipeline:$(PIPELINE_VERSION) &&             \
	    sleep 5 &&                                                      \
	    tries=3 &&                                                      \
	    while ! curl localhost:$(PORT)/ws/alive >/dev/null 2>/dev/null; \
	    do                                                              \
	        if [[ $$tries > 0 ]]; then                                  \
	            echo "Waiting for web service to be up..." >&2;         \
	            sleep 5;                                                \
	            (( tries-- ));                                          \
	        else                                                        \
	            echo "Gave up waiting for web service" >&2;             \
	            docker logs pipeline;                                   \
	            $(MAKE) pipeline-down;                                  \
	            exit 1;                                                 \
	        fi                                                          \
	    done                                                            \
	fi

.PHONY : pipeline-down
pipeline-down :
	docker stop pipeline;  \
	docker rm pipeline
