#!/bin/bash

acquire_lock() {
    lock_name="buildscript_lock"
    lock="$HOME/${lock_name}"

    exec 200>${lock}

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Attempting to acquire lock $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)

    # loop if we can't get the lock
    while true; do
        flock -n 200
        if [ $? -eq 0 ]; then
            break
        else
            printf "%c" "."
            sleep 5
        fi
    done

    # set the pid
    pid=$$
    echo ${pid} 1>&200

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Lock $($yellow)${lock}$($cyan) acquired. PID is $($yellow)${pid}$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
}

build() {
    source build/envsetup.sh
    export USE_CCACHE=1

    cd $DEVICEPATH_SCR
    mk_scr=`grep .mk AndroidProducts.mk | cut -d "/" -f "2"`
    product_scr=`grep "PRODUCT_NAME :=" $mk_scr | cut -d " " -f 3`
    cd ../../..

    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Starting build with target $($yellow)"$build_type_scr""$($cyan)" for"$($yellow)" $device_scr $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2s

    if [ "$telegram_scr" ]; then
        time_scr="$(date "+%r")"
        bash telegram -D -M "
        *Build for $device_scr started!*
        Product: *$product_scr*
        Target: *$build_type_scr*
        Started on: *$HOSTNAME* 
        Time: *$time_scr*"
    fi

    lunch "$product_scr"-userdebug
    make -j$(nproc) $build_type_scr |& tee build.log
}

clean_target() {
    if [ $clean_scr ] && [ ! $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning target $($yellow) $device_scr $($cyan)"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rvf $OUT_SCR
        printf "%s\n"
        sleep 2s
    elif [ $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning entire out"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        printf "%s\n"
        rm -rvf out
        sleep 2s
    fi
}

check_dependencies() {
    if [ ! $TELEGRAM_TOKEN ] && [ ! $TELEGRAM_CHAT ] && [ ! $G_FOLDER ]; then
        printf "You don't have TELEGRAM_TOKEN,TELEGRAM_CHAT,G_FOLDER set"
        exit
    fi

    if [ ! -f telegram ]; then
        echo "Telegram binary not present. Installing.."
        wget -q https://raw.githubusercontent.com/fabianonline/telegram.sh/master/telegram
        chmod +x telegram
    fi
}

print_help() {
    echo "Usage: `basename $0` [OPTION]";
    echo "  -s, --sync-android \ Sync current source" ;
    echo "  -b, --brand \ Brand name" ;
    echo "  -d, --device \ Device name" ;
    echo "  -t, --target \ Make target" ;
    echo "  -c, --clean \ Clean target" ;
    echo "  -ca, --cleanall \ Clean entire out" ;
    echo "  -tg, --telegram \ Enable telegram message" ;
    echo "  -u, --upload \ Enable drive upload" ;
    echo "  -r, --release \ Enable drive upload, tg msg and clean" ;
    exit
}

remove_lock() {
    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Removing $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
    exec 200>&-
}

setup_paths() {
    OUT_SCR=out/target/product/$device_scr
    DEVICEPATH_SCR=device/$brand_scr/$device_scr

    rm -rf build.log out/.lock $HOME/buildscript
    mkdir -p $HOME/buildscript
}

start_env() {
    rm -rf venv
    virtualenv2 venv
    source venv/bin/activate
}

sync_source() {
    if [ $sync_android_scr ]; then
        repo sync -j8 --force-sync --no-tags --no-clone-bundle -c
    fi
}

upload() {
    if [ $telegram_scr ] && [ ! $(grep -c "#### build completed successfully" build.log) -eq 1 ]; then
        bash telegram -D -M "
        *Build for $device_scr FAILED!*
        Product: *$product_scr*
        Target: *$build_type_scr*
        Started on: *$HOSTNAME*
        Time: *$time_scr*"
        bash telegram -f build.log
        exit
    fi

    case $build_type_scr in
        bacon)
            file=$(ls $OUT_SCR/*201*.zip | tail -n 1)
        ;;
        bootimage)
            file=$OUT_SCR/boot.img
        ;;
        recoveryimage)
            file=$OUT_SCR/recovery.img
        ;;
        dtboimage)
            file=$OUT_SCR/dtbo.img
        ;;
        systemimage)
            file=$OUT_SCR/system.img
        ;;
        vendorimage)
            file=$OUT_SCR/vendor.img
    esac

    if [ $upload_scr ]; then
        build_date_scr=$(date +%F_%H-%M)
        if [ $build_type_scr != "bacon" ]; then
            cp $file $HOME/buildscript/$build_type_scr"_"$device_scr"-"$build_date_scr.img
            file=`ls $HOME/buildscript/*.img | tail -n 1`
        fi

        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)

        if [ $telegram_scr ]; then
            zip_name=`echo $file | grep -o '[^/]*$'`
            bash telegram -D -M "
            *Build for $device_scr done!*
            Download: [$zip_name](https://drive.google.com/uc?export=download&id=$id) "
        fi
    fi
}

validate_arg() {
    valid=$(echo $1 | sed s'/^[\-][a-z0-9A-Z\-]*/valid/'g)
    [ "x$1" == "x$0" ] && return 0;
    [ "x$1" == "x" ] && return 0;
    [ "$valid" == "valid" ] && return 0 || return 1;
}

cyan='tput setaf 6'
yellow='tput setaf 3'
reset='tput sgr0'

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
            sync_android_scr=1
            ;;
        -b | --brand )
            brand_scr=$next_arg
            ;;
        -d | --device )
            device_scr=$next_arg
            ;;
        -t | --target )
            build_type_scr=$next_arg
            ;;
        -tg | --telegram )
            telegram_scr=1
            ;;
        -u | --upload )
            upload_scr=1
            ;;
        -r | --release )
            telegram_scr=1
            upload_scr=1
            clean_scr=1
            ;;
        -c | --clean )
            clean_scr=1
            ;;
        -ca | --clean-all )
            cleanall_scr=1
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

build_type_scr=${build_type_scr:-bacon}

if [ ! -z "$device_scr" ] && [ ! -z "$brand_scr" ]; then
    check_dependencies
    start_env
    setup_paths
    acquire_lock
    sync_source
    clean_target
    build $brand_scr $device_scr
    remove_lock
    upload
elif [ "$sync_android_scr" ]; then
    start_env
    sync_source
else
    print_help
fi