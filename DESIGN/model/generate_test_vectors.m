% =========================================================================
% Parameterized Test Vector Generator for Radix-2 DIF R2SDF FFT Cores
% Generates comprehensive multi-scenario stimulus and golden reference .mem files
% for arbitrary power-of-2 point sizes (N in 8, 16, 32, 64, 128, ...).
% =========================================================================

function generate_test_vectors(num_frames, N, B)
    if nargin < 1 || isempty(num_frames), num_frames = 100; end
    if nargin < 2 || isempty(N),          N = 32;          end
    if nargin < 3 || isempty(B),          B = 16;          end

    fprintf('=================================================================\n');
    fprintf('   PARAMETRIC TEST VECTOR GENERATOR: %d Frames, %d-Point, %d-Bit  \n', num_frames, N, B);
    fprintf('=================================================================\n');

    SCALE = 2^(B - 1);       % 32768 for B=16
    MAX_INT = SCALE - 1;     % +32767 for B=16
    MIN_INT = -SCALE;        % -32768 for B=16
    n = 0:(N - 1);

    total_samples = num_frames * N;
    all_stim_re = zeros(1, total_samples);
    all_stim_im = zeros(1, total_samples);
    all_gold_re = zeros(1, total_samples);
    all_gold_im = zeros(1, total_samples);

    rng(42); % Deterministic random seed for 100% reproducibility

    for f = 1:num_frames
        idx_range = (f - 1) * N + (1:N);

        % Select scenario based on frame index
        if f <= 16
            % Scenario 1: Single pure tones (sweeping f0 across bin frequencies)
            f0 = mod(f - 1, N / 2);
            amp = 0.85;
            phase = (f - 1) * pi / 8;
            sig = amp * exp(1j * (2 * pi * f0 * n / N + phase));

        elseif f <= 32
            % Scenario 2: Multi-tone complex signals
            f1 = mod(f * 3, N);
            f2 = mod(f * 7, N);
            sig = 0.45 * cos(2 * pi * f1 * n / N) + 0.35 * sin(2 * pi * f2 * n / N) + ...
                  1j * (0.35 * sin(2 * pi * f1 * n / N) - 0.45 * cos(2 * pi * f2 * n / N));

        elseif f <= 42
            % Scenario 3: Time-domain unit impulses (Kronecker deltas)
            pos = mod(f - 33, N);
            sig = zeros(1, N);
            sig(pos + 1) = 0.95 + 1j * 0.95;

        elseif f <= 52
            % Scenario 4: Nyquist, square waves, and alternating patterns
            if mod(f, 2) == 0
                sig = 0.80 * ((-1).^n) + 1j * 0.60 * ((-1).^n);
            else
                sig = 0.75 * sign(sin(2 * pi * 2 * n / N)) + 1j * 0.75 * sign(cos(2 * pi * 2 * n / N));
            end

        elseif f <= 62
            % Scenario 5: DC offsets and ramp signals
            dc_val = (mod(f, 5) - 2) * 0.25;
            ramp = (n / N) * 0.50;
            sig = (dc_val + ramp) + 1j * (dc_val - ramp);

        elseif f <= 77
            % Scenario 6: Extreme full-scale dynamic range (testing saturation & clamps)
            sig = (0.999 * cos(2 * pi * 5 * n / N)) + 1j * (0.999 * sin(2 * pi * 5 * n / N));

        elseif f <= 87
            % Scenario 7: Low amplitude signals (testing quantization floor)
            small_amp = 0.005 + (f - 77) * 0.002;
            sig = small_amp * exp(1j * 2 * pi * 3 * n / N);

        else
            % Scenario 8: Complex White Gaussian Noise (WGN)
            sig = (randn(1, N) + 1j * randn(1, N)) * 0.25;
        end

        % Quantize stimulus to B-bit signed fixed-point integer
        stim_r = max(MIN_INT, min(MAX_INT, round(real(sig) * SCALE)));
        stim_i = max(MIN_INT, min(MAX_INT, round(imag(sig) * SCALE)));
        all_stim_re(idx_range) = stim_r;
        all_stim_im(idx_range) = stim_i;

        % Compute Golden Reference Output using bit-reversed hardware model
        % Reconstruct normalized float from exact quantized input for 100% bit-accuracy
        sig_quant = (stim_r + 1j * stim_i) / SCALE;
        [~, X_int_hw] = fft_radix2_dif(sig_quant, N, B, 'bitrev');

        all_gold_re(idx_range) = real(X_int_hw);
        all_gold_im(idx_range) = imag(X_int_hw);
    end

    % Determine output file paths relative to script location
    script_dir = fileparts(mfilename('fullpath'));
    stim_fname = fullfile(script_dir, sprintf('stimulus_%d.mem', N));
    gold_fname = fullfile(script_dir, sprintf('golden_%d.mem', N));

    % Export to .mem files
    export_mem_file(stim_fname, all_stim_re, all_stim_im);
    export_mem_file(gold_fname, all_gold_re, all_gold_im);

    fprintf('  • Total Frames Generated : %d\n', num_frames);
    fprintf('  • Total Samples Exported : %d\n', total_samples);
    fprintf('  • Saved Stimulus File    : %s\n', stim_fname);
    fprintf('  • Saved Golden File      : %s\n', gold_fname);
    fprintf('=================================================================\n');
    fprintf('                 TEST VECTOR GENERATION COMPLETE                 \n');
    fprintf('=================================================================\n');
end

%% Helper: Write .mem hex file for Verilog $readmemh
function export_mem_file(fname, data_re, data_im)
    fid = fopen(fname, 'w');
    if fid == -1
        error('Cannot open file %s for writing.', fname);
    end
    for i = 1:length(data_re)
        r  = mod(int32(data_re(i)), 65536);
        im = mod(int32(data_im(i)), 65536);
        fprintf(fid, '%04X_%04X\n', r, im);
    end
    fclose(fid);
end
