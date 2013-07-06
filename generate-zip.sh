rm -rf dist temp

mkdir RandomAlbum
cp -R install.xml Plugin.pm strings.txt HTML RandomAlbum
mkdir dist
zip -r dist/RandomAlbum.zip RandomAlbum

VERSION=$(grep \<version\> install.xml  | perl -n -e '/>(.*)</; print $1;')
SHA=$(shasum dist/RandomAlbum.zip | awk '{print $1;}')

cat <<EOF > dist/public.xml
<extensions>
<details>
<title lang="EN">Random Album Plugin</title>
</details>
<plugins>
<plugin name="RandomAlbum" version="$VERSION" minTarget="7.5" maxTarget="*">
<title lang="EN">Random Album</title>
<desc lang="EN">Picks albums at random from your music library and displays them on a web page where they can be clicked to play. Works great on tablets where the standard web UI falls short.</desc>
<url>https://raw.github.com/anderskaplan/slim-random-album/master/dist/RandomAlbum.zip</url>
<link>https://github.com/anderskaplan/slim-random-album</link>
<sha>$SHA</sha>
<creator>Anders Kaplan</creator>
</plugin>
</plugins>
</extensions>
EOF
