(module
    (memory $memory 60)
    (export "memory" (memory $memory))
    (export "blur" (func $blur))

    ;; Approximation of the gaussian kernel e^-x^2
    ;; 1 / (1/0! + x(1/1! + x(1/2! + x(1/3! + x(1/4! + x(1/5!))))))
    (func $gaussian (param $x f64) (result f64)
        local.get $x
        local.get $x
        f64.mul
        local.set $x
        f64.const 1.0
        f64.const 1.0
        local.get $x
        f64.const 1.0
        local.get $x
        f64.const 0.5
        local.get $x
        f64.const 0.166666666666666667
        local.get $x
        f64.const 0.041666666666666667
        local.get $x
        f64.const 0.008333333333333333
        f64.mul
        f64.add
        f64.mul
        f64.add
        f64.mul
        f64.add
        f64.mul
        f64.add
        f64.mul
        f64.add
        f64.div
    )

    (func $blur (param $buffer i32) (param $backbuffer i32) (param $width i32) (param $height i32) (param $window i32) (param $blur f64)
        (local $x i32)
        (local $y i32)

        (local $scanstart i32)
        (local $stride i32)
        (local $samplepos i32)
        (local $readpos i32)
        (local $writepos i32)
        (local $winmax i32)

        (local $rtot f64)
        (local $gtot f64)
        (local $btot f64)
        (local $atot f64)
        (local $wtot f64)
        (local $weight f64)

        local.get $width
        i32.const 2
        i32.shl
        local.set $stride

        ;; HORIZONTAL PASS

        ;; Start reading at the beginning of the buffer
        local.get $buffer
        local.set $scanstart

        ;; Start writing at the beginning of the backbuffer
        local.get $backbuffer
        local.set $writepos

        ;; Loop over the pixels of the image
        i32.const 0
        local.set $y
        (loop $vscan
            i32.const 0
            local.set $x
            (loop $hscan
                f64.const 0.0
                local.tee $rtot
                local.tee $gtot
                local.tee $btot
                local.tee $atot
                local.set $wtot

                ;; Calculate the left edge of the window
                local.get $x
                local.get $window
                i32.sub
                local.tee $samplepos
                i32.const 0
                i32.lt_s
                if
                    i32.const 0
                    local.set $samplepos
                end

                ;; Calculate the right edge of the window
                local.get $x
                local.get $window
                i32.add
                local.tee $winmax
                local.get $width
                i32.gt_u
                if
                    local.get $width
                    local.set $winmax
                end

                ;; Calculate the initial readpos
                local.get $scanstart
                local.get $samplepos
                i32.const 2
                i32.shl
                i32.add
                local.set $readpos

                ;; Sample the horizontally neighboring pixels and accumulate a weighted sum of their colors
                (loop $sample
                    ;; Calculate the weight for the current sample using a gaussian kernel
                    local.get $samplepos
                    local.get $x
                    i32.sub
                    f64.convert_i32_s
                    local.get $blur
                    f64.div
                    call $gaussian
                    local.tee $weight
                    local.get $wtot
                    f64.add
                    local.set $wtot

                    ;; Weight the red channel and accumulate it
                    local.get $readpos
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $rtot
                    f64.add
                    local.set $rtot

                    ;; Weight the green channel and accumulate it
                    local.get $readpos
                    i32.const 1
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $gtot
                    f64.add
                    local.set $gtot

                    ;; Weight the blue channel and accumulate it
                    local.get $readpos
                    i32.const 2
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $btot
                    f64.add
                    local.set $btot

                    ;; Weight the alpha channel and accumulate it
                    local.get $readpos
                    i32.const 3
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $atot
                    f64.add
                    local.set $atot

                    ;; Increment readpos to the start of the next pixel
                    local.get $readpos
                    i32.const 4
                    i32.add
                    local.set $readpos

                    ;; Increment samplepos and loop back if it hasn't reached the right edge of the window
                    local.get $samplepos
                    i32.const 1
                    i32.add
                    local.tee $samplepos
                    local.get $winmax
                    i32.lt_u
                    br_if $sample
                )

                ;; Normalize rtot and store it in the backbuffer
                local.get $writepos
                local.get $rtot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize gtot and store it in the backbuffer
                local.get $writepos
                i32.const 1
                i32.add
                local.get $gtot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize btot and store it in the backbuffer
                local.get $writepos
                i32.const 2
                i32.add
                local.get $btot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize atot and store it in the backbuffer
                local.get $writepos
                i32.const 3
                i32.add
                local.get $atot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Increment writepos to the start of the next pixel
                local.get $writepos
                i32.const 4
                i32.add
                local.set $writepos

                ;; Increment x and loop back if it hasn't reached the right edge of the image
                local.get $x
                i32.const 1
                i32.add
                local.tee $x
                local.get $width
                i32.lt_u
                br_if $hscan
            )

            ;; Increment scanstart to the start of the next row
            local.get $scanstart
            local.get $stride
            i32.add
            local.set $scanstart

            ;; Increment y and loop back if it hasn't reached the bottom of the image
            local.get $y
            i32.const 1
            i32.add
            local.tee $y
            local.get $height
            i32.lt_u
            br_if $vscan
        )

        ;; VERTICAL PASS

        ;; Start writing at the beginning of the buffer
        local.get $buffer
        local.set $writepos

        ;; Loop over the pixels of the image
        i32.const 0
        local.set $y
        (loop $vscan
            ;; Start reading at the beginning of the backbuffer
            local.get $backbuffer
            local.set $scanstart

            i32.const 0
            local.set $x
            (loop $hscan
                f64.const 0.0
                local.tee $rtot
                local.tee $gtot
                local.tee $btot
                local.tee $atot
                local.set $wtot

                ;; Calculate the top edge of the window
                local.get $y
                local.get $window
                i32.sub
                local.tee $samplepos
                i32.const 0
                i32.lt_s
                if
                    i32.const 0
                    local.set $samplepos
                end

                ;; Calculate the bottom edge of the window
                local.get $y
                local.get $window
                i32.add
                local.tee $winmax
                local.get $height
                i32.gt_u
                if
                    local.get $height
                    local.set $winmax
                end

                ;; Calculate the initial readpos
                local.get $scanstart
                local.get $samplepos
                local.get $stride
                i32.mul
                i32.add
                local.set $readpos

                ;; Sample the vertically neighboring pixels and accumulate a weighted sum of their colors
                (loop $sample
                    ;; Calculate the weight for the current sample using a gaussian kernel
                    local.get $samplepos
                    local.get $y
                    i32.sub
                    f64.convert_i32_s
                    local.get $blur
                    f64.div
                    call $gaussian
                    local.tee $weight
                    local.get $wtot
                    f64.add
                    local.set $wtot

                    ;; Weight the red channel and accumulate it
                    local.get $readpos
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $rtot
                    f64.add
                    local.set $rtot

                    ;; Weight the green channel and accumulate it
                    local.get $readpos
                    i32.const 1
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $gtot
                    f64.add
                    local.set $gtot

                    ;; Weight the blue channel and accumulate it
                    local.get $readpos
                    i32.const 2
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $btot
                    f64.add
                    local.set $btot

                    ;; Weight the alpha channel and accumulate it
                    local.get $readpos
                    i32.const 3
                    i32.add
                    i32.load8_u
                    f64.convert_i32_u
                    local.get $weight
                    f64.mul
                    local.get $atot
                    f64.add
                    local.set $atot

                    ;; Increment readpos to the start of the next pixel
                    local.get $readpos
                    local.get $stride
                    i32.add
                    local.set $readpos

                    ;; Increment samplepos and loop back if it hasn't reached the bottom edge of the window
                    local.get $samplepos
                    i32.const 1
                    i32.add
                    local.tee $samplepos
                    local.get $winmax
                    i32.lt_u
                    br_if $sample
                )

                ;; Normalize rtot and store it in the buffer
                local.get $writepos
                local.get $rtot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize gtot and store it in the buffer
                local.get $writepos
                i32.const 1
                i32.add
                local.get $gtot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize btot and store it in the buffer
                local.get $writepos
                i32.const 2
                i32.add
                local.get $btot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Normalize atot and store it in the buffer
                local.get $writepos
                i32.const 3
                i32.add
                local.get $atot
                local.get $wtot
                f64.div
                i32.trunc_f64_u
                i32.store8

                ;; Increment writepos to the start of the next pixel
                local.get $writepos
                i32.const 4
                i32.add
                local.set $writepos

                ;; Increment scanstart to the start of the next column
                local.get $scanstart
                i32.const 4
                i32.add
                local.set $scanstart

                ;; Increment x and loop back if it hasn't reached the right edge of the image
                local.get $x
                i32.const 1
                i32.add
                local.tee $x
                local.get $width
                i32.lt_u
                br_if $hscan
            )

            ;; Increment y and loop back if it hasn't reached the bottom of the image
            local.get $y
            i32.const 1
            i32.add
            local.tee $y
            local.get $height
            i32.lt_u
            br_if $vscan
        )
    )
)
