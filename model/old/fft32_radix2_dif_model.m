% 32-Point Radix-2 Decimation-in-Frequency (DIF) R2SDF MATLAB Golden Model
% Architecture:
%   - 5 Stages with 5 Butterfly Processing Elements (R2SDF Pipeline)
%   - Natural Order Streaming Input -> Bit-Reversed Streaming Output
%   - Delay lines: Stage 1 (16), Stage 2 (8), Stage 3 (4), Stage 4 (2), Stage 5 (1)
%   - Fixed-Point: 16-bit Signed Q1.15
%   - Scaling: Stage Scaling (/2 per stage, total 1/32 normalized forward DFT)
%   - Rounding: Round-Half-Up (+1 before >>> 1)
%   - Saturation: Clamped to [-32768, +32767]
%   - Multipliers: Stages 1-3 (Full), Stage 4 (Mux x1/x-j), Stage 5 (Pass-through)

function [results] = fft32_radix2_dif_model()
    clc;
    close all;
    fprintf('=================================================================\n');
    fprintf('  32-POINT RADIX-2 DIF R2SDF FIXED-POINT MATLAB VERIFICATION   \n');
    fprintf('  Word Width: 16-bit Q1.15 | Scaling: /2 per stage (1/32 Total) \n');
    fprintf('=================================================================\n\n');

    N = 32;
    SCALE = 32768; % 2^15

    %% TEST 1: Multi-tone Complex Signal (k = 3 and k = 10)
    fprintf('--- Running Test 1: Multi-Tone Complex Sinusoid ---\n');
    n = 0:(N-1);
    f1 = 3; f2 = 10;
    sig_test1 = 0.50 * cos(2*pi*f1*n/N) + 0.30 * sin(2*pi*f2*n/N) + ...
                1j * (0.40 * sin(2*pi*f1*n/N) - 0.20 * cos(2*pi*f2*n/N));
    res1 = run_single_test('Multi-Tone', sig_test1, N, SCALE);

    %% TEST 2: Single-Tone Pure Real Sinusoid (k = 5)
    fprintf('\n--- Running Test 2: Single-Tone Real Sinusoid (k=5) ---\n');
    sig_test2 = 0.85 * cos(2*pi*5*n/N);
    res2 = run_single_test('Single-Tone', sig_test2, N, SCALE);

    %% TEST 3: Kronecker DC Impulse (x[0] = 0.95, others = 0)
    fprintf('\n--- Running Test 3: Kronecker DC Impulse ---\n');
    sig_test3 = zeros(1, N);
    sig_test3(1) = 0.95;
    res3 = run_single_test('Impulse', sig_test3, N, SCALE);

    %% TEST 4: Full-Scale Broadband Pseudo-Random Noise
    fprintf('\n--- Running Test 4: Broadband Random Noise ---\n');
    rng(12345); % Fixed seed for repeatable test vectors
    sig_test4 = (2*rand(1, N) - 1) * 0.70 + 1j * (2*rand(1, N) - 1) * 0.70;
    res4 = run_single_test('Broadband Noise', sig_test4, N, SCALE);

    %% Summary Table
    fprintf('\n=================================================================\n');
    fprintf('                     TEST VERIFICATION SUMMARY                   \n');
    fprintf('=================================================================\n');
    fprintf('  Test Case         | HW vs Algorithmic | Float SQNR | Status   \n');
    fprintf('--------------------+-------------------+------------+-----------\n');
    print_summary_line('Multi-Tone',      res1.hw_vs_alg_lsb, res1.sqnr_db);
    print_summary_line('Single-Tone',     res2.hw_vs_alg_lsb, res2.sqnr_db);
    print_summary_line('Impulse',         res3.hw_vs_alg_lsb, res3.sqnr_db);
    print_summary_line('Broadband Noise', res4.hw_vs_alg_lsb, res4.sqnr_db);
    fprintf('=================================================================\n\n');

    %% Generate and Save Comprehensive Verification Plots
    plot_verification_results(sig_test1, res1, N);

    %% Export Golden Test Vector Mem Files (Based on Multi-Tone Test 1)
    export_hex_vectors('stimulus_in.mem', res1.in_re_q15, res1.in_im_q15);
    export_hex_vectors('golden_out.mem', res1.out_hw_re, res1.out_hw_im);
    fprintf('Generated Golden Mem Test Vectors:\n');
    fprintf('  [1] model/stimulus_in.mem (32 samples, natural input order)\n');
    fprintf('  [2] model/golden_out.mem  (32 samples, bit-reversed hardware output)\n');
    fprintf('=================================================================\n');

    results = struct('test1', res1, 'test2', res2, 'test3', res3, 'test4', res4);
end

%% Single Test Execution Engine
function res = run_single_test(test_name, sig_float, N, SCALE)
    % 1. Quantize Input to 16-bit Q1.15 Signed Integers
    in_re_q15 = max(-32768, min(32767, round(real(sig_float) * SCALE)));
    in_im_q15 = max(-32768, min(32767, round(imag(sig_float) * SCALE)));

    % 2. Algorithmic Radix-2 DIF Fixed-Point Model
    [alg_re, alg_im] = r2dif_algorithmic_model(in_re_q15, in_im_q15, N);

    % 3. Cycle-Accurate 5-Stage R2SDF Hardware Pipeline Model
    % Feed 2 contiguous frames to verify streaming pipeline continuity
    stream_in_re = [in_re_q15, in_re_q15];
    stream_in_im = [in_im_q15, in_im_q15];
    [hw_stream_re, hw_stream_im] = r2sdf_pipeline_model(stream_in_re, stream_in_im);

    % Frame 1 emerges after exactly 31 cycles pipeline fill latency
    out_hw_re = hw_stream_re(1:32);
    out_hw_im = hw_stream_im(1:32);

    % 4. Double-Precision Floating Point Reference (fft(x) / 32)
    fft_float_norm = fft(sig_float) / N;

    % 5. Bit-Reversal Reordering for Spectral Comparison
    bit_rev_map = get_bit_reversed_indices(N);
    hw_reordered_re = zeros(1, N);
    hw_reordered_im = zeros(1, N);
    for k = 1:N
        nat_idx = bit_rev_map(k) + 1;
        hw_reordered_re(nat_idx) = out_hw_re(k) / SCALE;
        hw_reordered_im(nat_idx) = out_hw_im(k) / SCALE;
    end
    hw_complex = hw_reordered_re + 1j * hw_reordered_im;

    % 6. Discrepancy & SQNR
    hw_vs_alg_lsb = max([abs(out_hw_re - alg_re), abs(out_hw_im - alg_im)]);
    
    error_complex = hw_complex - fft_float_norm;
    sig_power = sum(abs(fft_float_norm).^2);
    noise_power = sum(abs(error_complex).^2);
    sqnr_db = 10 * log10(sig_power / max(1e-15, noise_power));

    fprintf('  - HW vs Algorithmic Discrepancy : %d LSBs\n', hw_vs_alg_lsb);
    fprintf('  - Floating-Point SQNR           : %.2f dB\n', sqnr_db);

    res = struct(...
        'name', test_name, ...
        'in_re_q15', in_re_q15, 'in_im_q15', in_im_q15, ...
        'out_hw_re', out_hw_re, 'out_hw_im', out_hw_im, ...
        'alg_re', alg_re, 'alg_im', alg_im, ...
        'hw_complex', hw_complex, 'fft_float_norm', fft_float_norm, ...
        'hw_vs_alg_lsb', hw_vs_alg_lsb, 'sqnr_db', sqnr_db);
end

%% Algorithmic Radix-2 DIF Fixed-Point Model
function [out_re, out_im] = r2dif_algorithmic_model(in_re, in_im, N)
    out_re = in_re;
    out_im = in_im;
    
    stage_lens = [16, 8, 4, 2, 1];
    for s = 1:5
        len = stage_lens(s);
        stride = len * 2;
        for start = 1:stride:N
            for k = 0:(len-1)
                idx_a = start + k;
                idx_b = start + k + len;
                
                ar = out_re(idx_a); ai = out_im(idx_a);
                br = out_re(idx_b); bi = out_im(idx_b);
                
                % Butterfly with Round-Half-Up & Divide-by-2
                sum_re  = sat_q15(floor((ar + br + 1) / 2));
                sum_im  = sat_q15(floor((ai + bi + 1) / 2));
                diff_re = sat_q15(floor((ar - br + 1) / 2));
                diff_im = sat_q15(floor((ai - bi + 1) / 2));
                
                % Twiddle factor W_32^tw_k
                tw_k = k * (32 / (len * 2));
                [tw_re, tw_im] = get_twiddle_q15(tw_k);
                
                % Complex multiplication
                [prod_re, prod_im] = cmult_q15_hardware(diff_re, diff_im, tw_re, tw_im, tw_k);
                
                out_re(idx_a) = sum_re;
                out_im(idx_a) = sum_im;
                out_re(idx_b) = prod_re;
                out_im(idx_b) = prod_im;
            end
        end
    end
end

%% Cycle-Accurate 5-Stage R2SDF Hardware Pipeline
function [stream_out_re, stream_out_im] = r2sdf_pipeline_model(in_re, in_im)
    delays   = [16, 8, 4, 2, 1];
    tw_steps = [1,  2, 4, 8, 0];
    
    cur_re = in_re;
    cur_im = in_im;
    
    for st = 1:5
        D = delays(st);
        tw_step = tw_steps(st);
        
        delay_buf_re = zeros(1, D);
        delay_buf_im = zeros(1, D);
        buf_ptr = 1;
        
        st_out_re = [];
        st_out_im = [];
        
        for n = 1:length(cur_re)
            clk_idx = n - 1;
            phase = mod(floor(clk_idx / D), 2);
            k = mod(clk_idx, D);
            
            in_r = cur_re(n);
            in_i = cur_im(n);
            
            emerging_r = delay_buf_re(buf_ptr);
            emerging_i = delay_buf_im(buf_ptr);
            
            if phase == 0
                % Phase 0: Loading new sample into delay buffer, flushing difference
                delay_buf_re(buf_ptr) = in_r;
                delay_buf_im(buf_ptr) = in_i;
                buf_ptr = mod(buf_ptr, D) + 1;
                
                % Twiddle multiplication on emerging difference sample
                tw_k = k * tw_step;
                [tw_re, tw_im] = get_twiddle_q15(tw_k);
                [p_r, p_i] = cmult_q15_hardware(emerging_r, emerging_i, tw_re, tw_im, tw_k);
                
                if n > D
                    st_out_re = [st_out_re, p_r];
                    st_out_im = [st_out_im, p_i];
                end
            else
                % Phase 1: Butterfly computation
                sum_r  = sat_q15(floor((emerging_r + in_r + 1) / 2));
                sum_i  = sat_q15(floor((emerging_i + in_i + 1) / 2));
                diff_r = sat_q15(floor((emerging_r - in_r + 1) / 2));
                diff_im = sat_q15(floor((emerging_i - in_i + 1) / 2));
                
                % Feed difference back into delay buffer
                delay_buf_re(buf_ptr) = diff_r;
                delay_buf_im(buf_ptr) = diff_im;
                buf_ptr = mod(buf_ptr, D) + 1;
                
                % Route sum directly to stage output
                st_out_re = [st_out_re, sum_r];
                st_out_im = [st_out_im, sum_i];
            end
        end
        cur_re = st_out_re;
        cur_im = st_out_im;
    end
    stream_out_re = cur_re;
    stream_out_im = cur_im;
end

%% Hardware-Accurate Q1.15 Complex Multiplier
function [yr, yi] = cmult_q15_hardware(xr, xi, wr, wi, tw_k)
    % Exact hardware bypass optimizations
    if tw_k == 0 % W = 1: Wire pass-through
        yr = xr; yi = xi;
        return;
    elseif tw_k == 8 % W = -j: (u + jv)(-j) = v - ju (Swap & Negate)
        yr = xi; yi = sat_q15(-xr);
        return;
    end
    
    % Four 16x16 signed real multipliers -> 32-bit Q2.30 products
    m1 = double(xr) * double(wr);
    m2 = double(xi) * double(wi);
    m3 = double(xr) * double(wi);
    m4 = double(xi) * double(wr);
    
    % 33-bit addition and subtraction
    prod_r = m1 - m2;
    prod_i = m3 + m4;
    
    % Round-Half-Up (+2^14 before >>> 15)
    rnd_r = floor((prod_r + 16384) / 32768);
    rnd_i = floor((prod_i + 16384) / 32768);
    
    yr = sat_q15(rnd_r);
    yi = sat_q15(rnd_i);
end

%% Twiddle Factor Table (Quantized 16-bit Q1.15)
function [wr, wi] = get_twiddle_q15(k)
    theta = -2 * pi * k / 32;
    wr = sat_q15(round(cos(theta) * 32768));
    wi = sat_q15(round(sin(theta) * 32768));
end

%% Saturation Helper
function y = sat_q15(x)
    y = max(-32768, min(32767, x));
end

%% 5-Bit Bit-Reversed Mapping Vector
function rev_map = get_bit_reversed_indices(N)
    rev_map = zeros(1, N);
    for x = 0:(N-1)
        r = 0;
        for i = 0:4
            if bitand(x, bitshift(1, i)) > 0
                r = bitor(r, bitshift(1, 4 - i));
            end
        end
        rev_map(x + 1) = r;
    end
end

%% Helper: Print Formatted Summary Line
function print_summary_line(name, lsb_err, sqnr)
    if lsb_err == 0 && sqnr > 60.0
        status_str = 'PASS [OK]';
    else
        status_str = 'FAIL';
    end
    fprintf('  %-17s |      %2d LSBs       |  %5.2f dB  | %s\n', name, lsb_err, sqnr, status_str);
end

%% Helper: Export Formatted Hex Vector File for Verilog Testbench
function export_hex_vectors(fname, data_re, data_im)
    fid = fopen(fname, 'w');
    if fid == -1
        error('Cannot open file %s for writing.', fname);
    end
    for i = 1:length(data_re)
        r = mod(int32(data_re(i)), 65536);
        im = mod(int32(data_im(i)), 65536);
        fprintf(fid, '%04X_%04X\n', r, im);
    end
    fclose(fid);
end

%% Helper: Generate Publication-Quality Verification Plots
function plot_verification_results(sig_float, res, N)
    try
        hFig = figure('Name', 'FFT32 R2SDF Fixed-Point Verification', ...
                      'Position', [100, 100, 1000, 750], 'Visible', 'off');

        % Subplot 1: Input Time-Domain Signal
        subplot(3, 1, 1);
        stem(0:(N-1), real(sig_float), 'b', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
        hold on;
        stem(0:(N-1), imag(sig_float), 'r--', 'LineWidth', 1.2, 'MarkerFaceColor', 'r');
        grid on;
        title('1. Time-Domain Input Stimulus (Multi-tone Sinusoid, k=3 & k=10)', 'FontSize', 11);
        xlabel('Sample Index (n)', 'FontSize', 10);
        ylabel('Normalized Amplitude', 'FontSize', 10);
        legend('Real Part', 'Imag Part', 'Location', 'northeast');
        xlim([-0.5, N-0.5]);

        % Subplot 2: Output Frequency Spectrum (Float vs Fixed-Point)
        subplot(3, 1, 2);
        k_axis = 0:(N-1);
        mag_float = abs(res.fft_float_norm);
        mag_hw    = abs(res.hw_complex);
        stem(k_axis, mag_float, 'k', 'LineWidth', 2.0, 'Marker', 'o', 'MarkerSize', 6);
        hold on;
        stem(k_axis, mag_hw, 'm--', 'LineWidth', 1.5, 'Marker', 'x', 'MarkerSize', 8);
        grid on;
        title(sprintf('2. Output Spectrum Magnitude Comparison (Float vs 16-bit Q1.15 R2SDF HW | SQNR = %.2f dB)', res.sqnr_db), 'FontSize', 11);
        xlabel('Frequency Bin Index (k)', 'FontSize', 10);
        ylabel('|X[k]| Normalized', 'FontSize', 10);
        legend('Ideal Double-Precision (fft/32)', 'Hardware Q1.15 R2SDF', 'Location', 'northeast');
        xlim([-0.5, N-0.5]);

        % Subplot 3: Absolute Quantization Error per Bin
        subplot(3, 1, 3);
        err_mag = abs(res.hw_complex - res.fft_float_norm);
        bar(k_axis, err_mag, 'FaceColor', [0.85, 0.33, 0.1], 'EdgeColor', [0.5, 0.1, 0.0]);
        grid on;
        title('3. Absolute Quantization Error per Frequency Bin (|X_{HW}[k] - X_{Float}[k]|)', 'FontSize', 11);
        xlabel('Frequency Bin Index (k)', 'FontSize', 10);
        ylabel('Error Magnitude', 'FontSize', 10);
        xlim([-0.5, N-0.5]);

        % Save figure to disk as PNG
        saveas(hFig, 'fft32_verification_plot.png');
        close(hFig);
        fprintf('Saved verification plot: model/fft32_verification_plot.png\n');
    catch ME
        fprintf('Note: Plot generation skipped or headless: %s\n', ME.message);
    end
end
