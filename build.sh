#!/bin/bash

cyan='tput setaf 6'
yellow='tput setaf 3'
reset='tput sgr0'

if [ ! $TELEGRAM_TOKEN ] && [ ! $TELEGRAM_CHAT ] && [ ! $G_FOLDER ]; then
    printf "You don't have TELEGRAM_TOKEN,TELEGRAM_CHAT,G_FOLDER set"
    exit
fi

if [ ! -f telegram ];
then
    echo "Telegram binary not present. Installing.."
    wget -q https://raw.githubusercontent.com/Dyneteve/misc/master/telegram
    chmod +x telegram
fi

if [ ! -d $HOME/buildscript ];
then
   mkdir $HOME/buildscript
fi

function validate_arg {
    valid=$(echo $1 | sed s'/^[\-][a-z0-9A-Z\-]*/valid/'g)
    [ "x$1" == "x$0" ] && return 0;
    [ "x$1" == "x" ] && return 0;
    [ "$valid" == "valid" ] && return 0 || return 1;
}

function print_help {
                echo "Usage: `basename $0` [OPTION]";
                echo "  -b, --brand \ Brand name" ;
                echo "  -d, --device \ Device name" ;
                echo "  -t, --target \ Make target" ;
                echo "  -c, --clean \ Clean target" ;
                echo "  -ca, --cleanall \ Clean entire out" ;
                echo "  -tg, --telegram \ Enable telegram message" ;
                echo "  -u, --upload \ Enable drive upload" ;
                echo "  -r, --Release \ Enable drive upload, tg msg and clean" ;
        exit
}

prev_arg=
while [ "$1" != "" ]; do
    cur_arg=$1

    # find arguments of the form --arg=val and split to --arg val
    if [ -n "`echo $cur_arg | grep -o =`" ]; then
        cur_arg=`echo $1 | cut -d'=' -f 1`
        next_arg=`echo $1 | cut -d'=' -f 2`
    else
        cur_arg=$1
        next_arg=$2
    fi

    case $cur_arg in

        -s | --sync-android )
            sync_android=1
            ;;
        -b | --brand )
            brand=$next_arg
            ;;
        -d | --device )
            device=$next_arg
            ;;
        -t | --target )
            build_type=$next_arg
            build_orig=$next_arg
            ;;
        -tg | --telegram )
            telegram=1
            ;;
        -u | --upload )
            upload=1
            ;;
        -r | --release )
            telegram=1
            upload=1
            clean=1
            ;;
        -c | --clean )
            clean=1
            ;;
        -ca | --clean-all )
            cleanall=1
            ;;
        *)
            validate_arg $cur_arg;
            if [ $? -eq 0 ]; then
                echo "Unrecognised option $cur_arg passed"
                print_help
            else
                validate_arg $prev_arg
                if [ $? -eq 1 ]; then
                    echo "Argument $cur_arg passed without flag option"
                    print_help
                fi
            fi
            ;;
    esac
    prev_arg=$1
    shift
done

sync_source() {
    if [ $sync_android ]; then
        repo sync -j8 --force-sync --no-tags --no-clone-bundle -c
    fi
}


setup_env() {
    rm -rf venv
    virtualenv2 venv
    source venv/bin/activate
    sync_source
}

clean_target() {
    if [ $clean ] && [ ! $cleanall ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning target $($yellow) $device $($cyan)"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf out/target/product/$device
        sleep 2
    elif [ $cleanall ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning entire out"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf out
        sleep 2s
    fi
}

upload() {

    if [ ! $(grep -c "#### build completed successfully" build.log) -eq 1 ]; then
        bash telegram -D -M "
        *Build for $device failed!*"
        bash telegram -f build.log
        exit
    fi

    case $build_type in
        bacon)
	        file=$(ls $OUT/*201*.zip | tail -n 1)
        ;;
		bootimage)
            file=$OUT/boot.img
        ;;
        recoveryimage)
            file=$OUT/recovery.img
        ;;
        dtbo)
            file=$OUT/dtbo.img
        ;;
        systemimage)
            file=$OUT/system.img
        ;;
        vendorimage)
            file=$OUT/vendor.img
    esac

    if [ -f $HOME/buildscript/*.img ]; then
        rm $HOME/buildscript/*.img
    fi

    OUT=out/target/product/$device

    build_date=$(date +%F_%H-%M)
    if [ ! -z $build_orig ] && [ $upload ]; then
        cp $file $HOME/buildscript/"$build_type"-"$build_date".img
        file=`ls $HOME/buildscript/*.img | tail -n 1`
        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
    elif [ -z $build_orig ] && [ $upload ]; then
        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
    fi

    if [ $telegram ] && [ $upload ]; then
        bash telegram -D -M "
        *Build for $device done!*
        Download: [Drive](https://drive.google.com/uc?export=download&id=$id) "
    fi
}

build() {

    source build/envsetup.sh
    export USE_CCACHE=1
    rm build.log

    if [ -z "$build_type" ]; then
        build_type=bacon
    fi

    cd device/$brand/$device
    mk=`grep .mk AndroidProducts.mk | cut -d "/" -f "2"`
    product=`grep "PRODUCT_NAME :=" $mk | cut -d " " -f 3`
    cd ../../..

    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Starting build with target $($yellow)"$build_type""$($cyan)" for"$($yellow)" $device $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2s

    if [ "$telegram" ]; then
        bash telegram -D -M "
        *Build for $device started!*
        Product: *$product*
        Target: *$build_type*
        Started on: *$HOSTNAME* 
        Time: *$(date "+%r")* "
    fi

    ln_prd=$product
    lunch "$ln_prd"-userdebug
    mka $build_type |& tee build.log
}

if [ ! -z "$device" ] && [ ! -z "$brand" ]; then
    setup_env
    clean_target
    build $brand $device
    upload
else
    print_help
fi

