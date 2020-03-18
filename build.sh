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

    if [ -d $DEVICEPATH_SCR ]; then
        cd $DEVICEPATH_SCR
        mk_scr=$(grep .mk AndroidProducts.mk | cut -d "/" -f "2")
        product_scr=$(grep "^PRODUCT_NAME :=" $mk_scr | cut -d " " -f 3)
        cd ../../..
    else
        printf "$($yellow)Device tree$($reset) $($cyan)not present. Exiting..$($reset)\n"
        remove_lock
        exit
    fi

    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Starting build with target $($yellow)"$build_target_scr""$($cyan)" for"$($yellow)" $device_scr $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2s

    if [ "$telegram_scr" ]; then
        time_scr="$(date "+%r")"
        bash telegram -D -M "
        *Build for $device_scr started!*
        Product: *$product_scr*
        Target: *$build_target_scr*
        Build Variant: *$build_variant_scr*
        Started on: *$HOSTNAME* 
        Time: *$time_scr*"
    fi

    lunch "$product_scr"-"$build_variant_scr"
    make -j$(nproc) $build_target_scr |& tee build.log

    if [ ! $(grep -c "#### build completed successfully" build.log) -eq 1 ]; then
        if [ $telegram_scr ]; then
            bash telegram -D -M "
            *Build for $device_scr FAILED!*
            Product: *$product_scr*
            Target: *$build_target_scr*
            Build Variant: *$build_variant_scr*
            Started on: *$HOSTNAME*
            Time: *$time_scr*"
            bash telegram -f build.log
        fi
        exit
    fi
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
        printf "$($yellow)\$TELEGRAM_TOKEN, \$TELEGRAM_CHAT, \$G_FOLDER$($reset) $($red)not set.$($reset)\nExport it in your shell rc.\n\n$($cyan)export TELEGRAM_TOKEN=<token>\nexport TELEGRAM_CHAT=<chat-id>\nexport G_FOLDER=<folder-id>$($reset)\n"
        exit
    fi

    if [ ! -f telegram ]; then
        printf "$($yellow)telegram.sh$($reset) $($cyan)not present in current directory. Fetching..$($reset)\n"
        wget -q https://raw.githubusercontent.com/fabianonline/telegram.sh/master/telegram
        chmod +x telegram
    fi
}

print_help() {
    echo "Usage: $(basename $0) [OPTION]"
    echo "  -s, --sync-android \ Sync current source"
    echo "  -b, --brand \ Brand name"
    echo "  -d, --device \ Device name"
    echo "  -t, --target \ Make target"
    echo "  -bt, --build-type \ Build type"
    echo "  -c, --clean \ Clean target"
    echo "  -ca, --cleanall \ Clean entire out"
    echo "  -tg, --telegram \ Enable telegram message"
    echo "  -u, --upload \ Enable drive upload"
    echo "  -r, --release \ Enable drive upload, tg msg and clean"
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

set_colors() {
    cyan='tput setaf 6'
    yellow='tput setaf 3'
    red='tput setaf 1'
    reset='tput sgr0'
}

setup_paths() {
    OUT_SCR=out/target/product/$device_scr
    DEVICEPATH_SCR=device/$brand_scr/$device_scr

    rm -rf build.log out/.lock $HOME/buildscript
    mkdir -p $HOME/buildscript
}

start_venv() {
    python_version=$(python --version)
    if [ "${python_version:0:8}" = "Python 3" ]; then
        rm -rf venv
        virtualenv2 venv
        source venv/bin/activate
        printf "\n"
    fi
}

strip_args() {
    prev_arg=
    while [ "$1" != "" ]; do
        cur_arg=$1

        # find arguments of the form --arg=val and split to --arg val
        if [ -n "$(echo $cur_arg | grep -o =)" ]; then
            cur_arg=$(echo $1 | cut -d'=' -f 1)
            next_arg=$(echo $1 | cut -d'=' -f 2)
        else
            cur_arg=$1
            next_arg=$2
        fi

        case $cur_arg in
        -s | --sync-android)
            sync_android_scr=1
            ;;
        -b | --brand)
            brand_scr=$next_arg
            ;;
        -d | --device)
            device_scr=$next_arg
            ;;
        -t | --target)
            build_target_scr=$next_arg
            ;;
        -bt | --build-type)
            build_variant_scr=$next_arg
            ;;
        -tg | --telegram)
            telegram_scr=1
            ;;
        -u | --upload)
            upload_scr=1
            ;;
        -r | --release)
            telegram_scr=1
            upload_scr=1
            clean_scr=1
            ;;
        -c | --clean)
            clean_scr=1
            ;;
        -ca | --clean-all)
            cleanall_scr=1
            ;;
        *)
            validate_arg $cur_arg
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

    build_target_scr=${build_target_scr:-bacon}
    build_variant_scr=${build_variant_scr:-userdebug}
}

sync_source() {
    if [ $sync_android_scr ]; then
        repo sync -v --force-sync --current-branch --no-tags --no-clone-bundle --optimized-fetch --prune -j8
        printf "\n"
    fi
}

upload() {
    case $build_target_scr in
    bacon)
        file=$(ls $OUT_SCR/*202*.zip | tail -n 1)
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
        ;;
    esac

    if [ $upload_scr ]; then
        build_date_scr=$(date +%F_%H-%M)
        if [ $build_target_scr != "bacon" ]; then
            cp $file $HOME/buildscript/$build_target_scr"_"$device_scr"-"$build_date_scr.img
            file=$(ls $HOME/buildscript/*.img | tail -n 1)
        fi

        for tries in {1..3}; do
            id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
            zip_name=$(echo $file | grep -o '[^/]*$')

            if [ ! -z $id ]; then
                if [ $telegram_scr ]; then
                    bash telegram -D -M "
                    *Build for $device_scr done!*
                    Download: [$zip_name](https://drive.google.com/uc?export=download&id=$id) "
                fi
                break
            else
                bash telegram -D -M "
                *Upload for $device_scr FAILED!* (Try \`$tries/3\`)
                File: \`$zip_name\`"
            fi
        done
    fi
}

validate_arg() {
    valid=$(echo $1 | sed s'/^[\-][a-z0-9A-Z\-]*/valid/'g)
    [ "x$1" == "x$0" ] && return 0
    [ "x$1" == "x" ] && return 0
    [ "$valid" == "valid" ] && return 0 || return 1
}

clear
strip_args $@
if [ ! -z "$device_scr" ] && [ ! -z "$brand_scr" ]; then
    set_colors
    check_dependencies
    start_venv
    acquire_lock
    sync_source
    setup_paths
    clean_target
    build $brand_scr $device_scr
    remove_lock
    upload
elif [ "$sync_android_scr" ]; then
    start_venv
    sync_source
else
    print_help
fi
