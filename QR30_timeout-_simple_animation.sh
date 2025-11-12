#!/bin/bash

dim_time=15               # seconds before dimming keyboard
now_idle=false            # whether user is idle
active_brightness_level=4 # from 0 to 10.  
idle_brightness_level=0   # from 0 to 10.

priority=19               # CPU priority for this script
tmp_file="/tmp/wprintidle_output.txt"


#Animations parameters 

# time to wait after a animation settle
animation_end_sleep=0.3

# became idle
start_brightness_animation_idle="$active_brightness_level"
steps_animation_idle=-4               # can be positive or negative
step_multiplier_animation_idle=1     
period_animation_idle=0.15           
target_animated_animation_idle=true  #when idle like watching youtube. I want it to turn off

# became active
start_brightness_animation_active="$idle_brightness_level"
steps_animation_active=4               # can be positive or negative
step_multiplier_animation_active=1     
period_animation_active=0.15          # default 1 second
target_animated_animation_active=true  #when idle like watching youtube. I want it to turn off


# increase volume
start_brightness_animation=4
steps_animation=4               # can be positive or negative
step_multiplier_animation=2     
period_animation=0.2
target_brightness_animation=10  # I want to turn off after animation
target_animated_animation=true  #when idle like watching youtube. I want it to turn off

# decrease volume
start_brightness_animation_decrease=4
steps_animation_decrease=-4               # can be positive or negative
step_multiplier_animation_decrease=1     
period_animation_decrease=0.2
target_brightness_animation_decrease=1   # I want to turn off after animation
target_animated_animation_decrease=true  #when idle like watching youtube. I want it to turn off


# Set low priority
renice "$priority" "$$" >/dev/null

# --- find correct hidraw device ---
find_qr30_hidraw() {
    for dev in /dev/hidraw*; do
        [[ ! -e "$dev" ]] && continue
        # get properties
        udev=$(udevadm info -q property -n "$dev")
        VID=$(echo "$udev" | grep ^ID_VENDOR_ID= | cut -d= -f2 | tr -d '[:space:]')
        PID=$(echo "$udev" | grep ^ID_MODEL_ID= | cut -d= -f2 | tr -d '[:space:]')
        IFACE=$(echo "$udev" | grep ^ID_USB_INTERFACE_NUM= | cut -d= -f2 | tr -d '[:space:]')
        
        # normalize interface number: remove leading zero
        #IFACE=$((10#$IFACE))
        
        if [[ "$VID" == "2d99" && "$PID" == "a101" && "$IFACE" -eq "03" ]]; then
            echo "$dev"
            return
        fi
    done
}

HIDRAW=$(find_qr30_hidraw)
if [[ -z "$HIDRAW" ]]; then
    echo "QR30 device not found"
fi
echo "Using HIDRAW: $HIDRAW"

# All set-brighteness packages from Edifier QR30
declare -A SEND_BRIGHTNESS
SEND_BRIGHTNESS[0]="2eaaec6b00070d0b02000000ff2100000000000000000000000000000000000000"
SEND_BRIGHTNESS[1]="2eaaec6b00070d0b0200000aff2b00000000000000000000000000000000000000"
SEND_BRIGHTNESS[2]="2eaaec6b00070d0b02000014ff35000000000000000000000000000000000000"
SEND_BRIGHTNESS[3]="2eaaec6b00070d0b0200001eff3f000000000000000000000000000000000000"
SEND_BRIGHTNESS[4]="2eaaec6b00070d0b02000028ff49000000000000000000000000000000000000"
SEND_BRIGHTNESS[5]="2eaaec6b00070d0b02000032ff53000000000000000000000000000000000000"
SEND_BRIGHTNESS[6]="2eaaec6b00070d0b0200003cff5d000000000000000000000000000000000000"
SEND_BRIGHTNESS[7]="2eaaec6b00070d0b02000046ff67000000000000000000000000000000000000"
SEND_BRIGHTNESS[8]="2eaaec6b00070d0b02000050ff71000000000000000000000000000000000000"
SEND_BRIGHTNESS[9]="2eaaec6b00070d0b0200005aff7b000000000000000000000000000000000000"
SEND_BRIGHTNESS[10]="2eaaec6b00070d0b02000064ff85000000000000000000000000000000000000"

# --- send hex to speaker ---
send_hidraw() {
    local hex="$1"
    echo "$hex" | xxd -r -p | dd bs=64 count=1 conv=sync of=$(find_qr30_hidraw) >/dev/null 2>&1

}

#I don't query it because it may be needed to fire a stream of interrupts to receive it
# remember to use the same number os steps otherwhise up and down or not, I don't care
varies_brightness_steps() {
    local start="$1" steps="$2" step_size="${3:-1}" period="${4:-1}" target="$5" target_animated="${6:-true}"
    period=$(awk "BEGIN {print ($period<0.1 ? 0.1 : $period)}")

    # If steps not set, calculate
    if [[ -z "$steps" && "$target" =~ ^[0-9]+$ ]]; then
        steps=$(( target - start ))
    fi

    local current=$start
    send_hidraw "${SEND_BRIGHTNESS[$current]}"
    sleep "$period"
    
    local direction=$(( steps > 0 ? 1 : -1 ))
    local abs_steps=$(( steps < 0 ? -steps : steps ))

    for ((i=0; i<abs_steps; i++)); do
        local diff=$(( target - current ))
        if (( direction * diff < step_size )); then
            current=$target
        else
            current=$(( current + direction * step_size ))
        fi

        (( current > 10 )) && current=10
        (( current < 0 )) && current=0

        send_hidraw "${SEND_BRIGHTNESS[$current]}"
        sleep "$period"
    done

    # final step to target if needed
    if [[ "$target" =~ ^[0-9]+$ && "$current" != "$target" ]]; then
        if [[ "$target_animated" == "true" ]]; then
            while (( current != target )); do
                local diff=$(( target - current ))
                local dir=$(( diff > 0 ? 1 : -1 ))
                if (( step_size > (diff > 0 ? diff : -diff) )); then
                    current=$target
                else
                    current=$(( current + dir * step_size ))
                fi
                send_hidraw "${SEND_BRIGHTNESS[$current]}"
                sleep "$period"
            done
        else
            current=$target
            send_hidraw "${SEND_BRIGHTNESS[$current]}"
        fi
    fi
}




get_idle_time() {
    
    # Check if wprintidle is already running
    if ! pgrep -x "wprintidle" > /dev/null; then
        # If not, start wprintidle in the background and redirect output to a file
        printidle > "$tmp_file" &
        echo "wprintidle started in the background."
    fi
        
    # Send USR2 signal to wprintidle to force it to update the idle time
    pkill -USR2 wprintidle
    # get the idle time
    clean_idle_time=$(tr -d '\0' < "$tmp_file" | tail -n 1)    
    # replace values there to not be without memory
    echo "$clean_idle_time" > "$tmp_file"
    
    echo "$clean_idle_time" | awk '{print $1/1000}'
    
}

# Variable to track if volume changed recently
volume_changed_during_idle=false
idle_addition=0

# Get idle time using qdbus (for any wayland compatible with wprintidle DE)
idle_time0=$(get_idle_time)

send_hidraw "${SEND_BRIGHTNESS[$active_brightness_level]}"

while true; do


    idle_time=$(awk -v base="$(get_idle_time)" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
    
    is_greater=$(awk -v t0="$idle_time0" -v t1="$idle_time" 'BEGIN{print (t0 > t1)}')
    
     if [ "$is_greater" -eq 1 ]; then
        # idle_time0 > idle_time, do something
        
        idle_time=$(get_idle_time)
        idle_addition=0
    fi
            
            
            
    # Save previous volume if not set
    if ! [ -v volume_before ]; then
        volume_before=$(wpctl get-volume @DEFAULT_SINK@)
    fi

    # Compare volumes
    volume_now=$(wpctl get-volume @DEFAULT_SINK@)
    if [ "$volume_before" != "$volume_now" ]; then
        volume_changed_during_idle=true
         
        # Compare volumes 
    
        comp=$(awk -v new="$volume_now" -v old="$volume_before" 'BEGIN{if(new>old) print 1; else if(new<old) print -1; else print 0}')
        
        if [ "$now_idle" = true ]; then
        
            target_animated_current="$idle_brightness_level"
            
        elif [ "$now_idle" = false ]; then
        
            target_animated_current="$active_brightness_level"
            
        fi
        
        if (( comp == 1 && $(date +%s%3N) - animvol_change_time > 1100 )); then
            varies_brightness_steps "$start_brightness_animation" "$steps_animation" "$step_multiplier_animation" "$period_animation" "$target_brightness_animation" "$target_animated_animation"
            varies_brightness_steps "$target_brightness_animation" "" "$step_multiplier_animation" "$period_animation" "$target_animated_current" "$target_animated_animation"
            animvol_change_time=$(date +%s%3N)
            echo "volume increase"
            sleep "$animation_end_sleep"
        
        elif (( comp == -1 && $(date +%s%3N) - animvol_change_time > 1100 )); then
        
            varies_brightness_steps "$start_brightness_animation_decrease" "$steps_animation_decrease"  "$step_multiplier_animation_decrease" "$period_animation_decrease"  "$target_brightness_animation_decrease" "$target_animated_animation_decrease"
            varies_brightness_steps "$target_brightness_animation_decrease" ""  "$step_multiplier_animation_decrease" "$period_animation_decrease"  "$target_animated_current" "$target_animated_animation_decrease"
            animvol_change_time=$(date +%s%3N)
            echo "volume decrease"
            sleep "$animation_end_sleep"
        else
            echo "unchanged"
        fi
        
        volume_change_time=$(date +%s%3N)
    fi
    volume_before="$volume_now"

    # Became idle
    # I want to watch videos in darkness so
    if (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{print (idle >= time)}') )) && [ "$now_idle" = false ]; then
        echo "entrando em idle"
        varies_brightness_steps "$start_brightness_animation_idle" "$steps_animation_idle"  "$step_multiplier_animation_idle" "$period_animation_idle" "$idle_brightness_level" "$target_animated_animation_idle"
        sleep "$animation_end_sleep"
        
        idle_addition=0
        now_idle=true

    # Became active
    elif (( $(awk -v idle="$idle_time" -v time="$dim_time" 'BEGIN{print (idle < time)}') )) && [ "$now_idle" = true ]; then
        current_time=$(date +%s%3N)

        # Ignore brief wake caused by volume change
        # 1000 ms of sensibility of volume
        if [ "$volume_changed_during_idle" = true ] && (( current_time - volume_change_time < 1000 )); then
            idle_addition=$(awk -v base="$dim_time" -v factor="$dim_time" 'BEGIN {print base * factor}')
            # do nothing, still considered idle
        else
            now_idle=false
            volume_changed_during_idle=false
            
            echo "became active"
            varies_brightness_steps "$start_brightness_animation_active" "$steps_animation_active"  "$step_multiplier_animation_active" "$period_animation_active" "$active_brightness_level" "$target_animated_animation_active"
            sleep "$animation_end_sleep"
        fi
        
    fi
    
    idle_time0=$(awk -v base="$(get_idle_time)" \
            -v add="$idle_addition" 'BEGIN{print base + add}')
        
    sleep 0.3
done

