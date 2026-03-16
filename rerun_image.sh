sudo bash cleandocker.sh
# docker stop $(docker ps -aq)
# docker rm $(docker ps -aq)
sudo docker build -t ghcr.io/liveqte/ff_lite:latest -f ff_dockerfile .
sudo docker run -itd -p 8080:8080 -p 8082:8082 -e FF_MAG=1 -e FFMAG_PASS=123 ghcr.io/liveqte/ff_lite:latest

# docker push ghcr.io/liveqte/ff_lite:latest