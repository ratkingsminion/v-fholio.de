#!/bin/bash

source upload_config.sh

# TODO ignore-time also ignores if the file changed but not the size!
lftp -f "
	open $HOST
	user $USER $PASS
	mirror --reverse --delete --ignore-time --verbose $SOURCEFOLDER $TARGETFOLDER --exclude teaching/ --exclude things/ --exclude archive/
	bye
	"

echo "Upload completed"